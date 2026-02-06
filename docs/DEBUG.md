# Debug Analysis: ROCm GPU Detection Failure

## Problem Statement

After setting up the Docker-based Whisper ROCm environment, attempting to run transcription with `--device cuda` resulted in:

```
RuntimeError: Attempting to deserialize object on a CUDA device but torch.cuda.is_available() is False.
If you are running on a CPU-only machine, please use torch.load with map_location=torch.device('cpu')
to map your storages to the CPU.
```

Despite mounting GPU devices (`/dev/kfd`, `/dev/dri`) and using `--group-add video`, PyTorch could not detect the AMD ROCm GPU.

---

## Root Cause Analysis (3 Bugs Found)

### Bug #1: NumPy Version Incompatibility with Numba

**Symptom:**

```
ImportError: Numba needs NumPy 2.3 or less. Got NumPy 2.4.
```

**Debug Process:**

1. After initial build, container failed when trying to import numba (a dependency of Whisper)
2. Checked installed versions:
   ```bash
   pip show numpy | grep Version
   # Output: 2.4.1
   ```
3. Checked numba requirements online and found:
   - Numba 0.63.x requires NumPy ≤2.3
   - NumPy 2.4.x removed support for some legacy APIs numba relies on

**Solution Applied:**
Changed Dockerfile line 18 from `numpy==2.4.1` to:

```dockerfile
numpy==2.3.5 \
```

---

### Bug #2: Missing llvmlite Dependency

**Symptom:**

```
ModuleNotFoundError: No module named 'llvmlite'
```

**Debug Process:**

1. After fixing NumPy version, tried manual import:
   ```bash
   docker compose run --rm whisper python3 -c "import numba"
   # Failed with ModuleNotFoundError
   ```
2. Checked numba's dependencies:
   ```bash
   pip show numba
   # Output shows: Requires: llvmlite
   ```
3. Tested installing llvmlite:
   ```bash
   docker compose run --rm whisper pip install llvmlite==0.46.0
   # Import worked after this
   ```

**Root Cause:**
The Dockerfile uses `--no-deps` flag when installing Whisper to avoid conflicts with ROCm's PyTorch, but this also skipped llvmlite.

**Solution Applied:**
Added explicit llvmlite installation in Dockerfile:

```dockerfile
llvmlite==0.46.0 \
```

---

### Bug #3: ROCm Device Access - GID Mismatch (THE CRITICAL ONE)

**Symptom:**

```
RuntimeError: Attempting to deserialize object on a CUDA device but torch.cuda.is_available() is False.
```

**Debug Process (Step-by-Step):**

#### Step 1: Test with direct docker run (worked)

```bash
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  rocm/pytorch:latest python3 -c "import torch; print(torch.cuda.is_available())"
# Output: True ✅
```

#### Step 2: Test with user mapping (failed)

```bash
docker run --rm \
  --user 1000:1000 \
  --device=/dev/kfd \
  --device=/dev/dri \
  rocm/pytorch:latest python3 -c "import torch; print(torch.cuda.is_available())"
# Output: False ❌
```

#### Step 3: Check device permissions on host

```bash
ls -la /dev/kfd /dev/dri/renderD*
# Output:
# crw-rw---- 1 root render 234, 0 Feb 05 09:35 /dev/kfd
# crw-rw---- 1 root render 226, 128 Feb 05 09:35 /dev/dri/renderD128
```

Devices are owned by `root:render`, meaning only members of the **render** group can access them.

#### Step 4: Check host group IDs

```bash
getent group video
# Output: video:x:44

getent group render
# Output: render:x:110:ollama,zettlrobert
```

- Host `video` group GID = **44**
- Host `render` group GID = **110**

#### Step 5: Check what docker-compose.yml is doing

The original `docker-compose.yml` had:

```yaml
group_add:
  - video
  - render
```

These are **group names**, not IDs.

#### Step 6: Check container's group membership

```bash
docker compose run --rm whisper id
# Output: uid=1000 gid=1000 groups=1000,44(video),991(render)
```

**FOUND THE ISSUE!**

- Host `render` group GID = **110**
- Container's `render` group GID = **991** (Docker's internal mapping)

#### Step 7: Verify device ownership vs container groups

```bash
# Device on host:
crw-rw---- 1 root render 234, 0 Feb 05 09:35 /dev/kfd

# Container sees:
groups=...991(render)  # ≠ 110!

# Result: No permission to access /dev/kfd ❌
```

**Why this happens:**
Docker maps group names to GIDs within the container namespace. When you specify `group_add: render`, Docker finds the **container's** `render` group (GID 991) and adds the user to it, not the host's `render` group (GID 110).

The device `/dev/kfd` is owned by host GID 110, so the container process with group 991 has no access.

#### Step 8: Solution - Use Numeric GIDs

Changed `docker-compose.yml` to use numeric GIDs:

```yaml
group_add:
  - '44' # video (host GID)
  - '110' # render (host GID)
```

Now when Docker processes `"110"`, it directly adds the user to group 110 without looking up a name, matching the host's device permissions.

#### Step 9: Verification

```bash
docker compose run --rm whisper id
# Output: uid=1000 gid=1000 groups=1000,44(video),110(render)

docker compose run --rm whisper python3 -c "import torch; print(torch.cuda.is_available())"
# Output: True ✅
```

---

## Files Modified

### 1. `setup.sh`

- **Added**: Dynamic GID detection
  ```bash
  VIDEO_GID=$(getent group video | cut -d: -f3 || echo "44")
  RENDER_GID=$(getent group render | cut -d: -f3 || echo "110")
  ```
- **Updated**: `.zshrc` exports now include `VIDEO_GID` and `RENDER_GID`
- **Fixed**: whisper-gpu function uses detected GIDs as defaults

### 2. `docker-compose.yml`

- **Changed**: `group_add` from names to environment variables with fallbacks:
  ```yaml
  group_add:
    - '${VIDEO_GID:-44}'
    - '${RENDER_GID:-110}'
  ```

### 3. `Dockerfile`

- **Added**: Explicit llvmlite dependency:
  ```dockerfile
  llvmlite==0.46.0 \
  ```
- **Kept**: NumPy version compatible with numba: `numpy==2.3.5`

---

## System Portability Notes

### Why Numeric GIDs Are Used

The solution uses hardcoded numeric GIDs (44, 110) as defaults, which are specific to this system's group configuration.

**On another AMD system:**

- `getent group video` might output different GID
- `getent group render` might output different GID

### Making It Truly Portable

The setup script now detects GIDs automatically:

```bash
VIDEO_GID=$(getent group video | cut -d: -f3 || echo "44")
RENDER_GID=$(getent group render | cut -d: -f3 || echo "110")
```

These values are exported to `~/.zshrc` and used by the whisper-gpu function.

### Manual GID Check

To verify your system's GIDs:

```bash
# Check video group
getent group video
# Format: video:x:<GID>:<members>

# Check render group
getent group render
# Format: render:x:<GID>:<members>
```

### Fallback Behavior

If `getent` fails (e.g., groups don't exist), the script defaults to:

- `VIDEO_GID=44`
- `RENDER_GID=110`

These are common GIDs on Debian/Ubuntu systems but may differ on other distributions.

---

## Summary Table

| Bug                | Symptom                         | Root Cause                              | Solution                           |
| ------------------ | ------------------------------- | --------------------------------------- | ---------------------------------- |
| NumPy version      | Numba import error              | NumPy ≥2.4 incompatible with numba      | `numpy==2.3.5` in Dockerfile       |
| llvmlite missing   | Import error with --no-deps     | llvmlite not installed                  | `llvmlite==0.46.0` in Dockerfile   |
| ROCm device access | torch.cuda.is_available()=False | GID mismatch between host and container | Use numeric `"${RENDER_GID:-110}"` |

---

## Testing Checklist

After setup, verify:

```bash
# 1. Check environment variables are exported
echo $HSA_OVERRIDE_GFX_VERSION
echo $VIDEO_GID
echo $RENDER_GID

# 2. Test GPU detection
whisper-gpu --help

# 3. Quick test with Python
docker compose run --rm whisper python3 -c "import torch; print(torch.cuda.is_available())"
```
