# Measured Roblox + Studio MCP gotchas

Each of these cost a session once. Read before the first Studio call; if you
keep a playbook, put the engineering details for them in
`PB/engineering/studio-mcp.md`.

## Pushing code
- **`set_script_source` / `edit_script_lines` turn `\n` in strings into real
  newlines** → "Malformed string" at runtime, while the push reports success.
  Push source as an `.rbxmx` (ProtectedString in CDATA, `]]>` escaped as
  `]]]]><![CDATA[>`) and `import_rbxm {path}`. Keep a small converter script
  in your project for this (for example `tools/luau_to_rbxmx.py`; the
  `roblox-trailer` skill's `build_kit.py` does the same escaping). This also
  keeps source out of context.
- **`require` caches across `execute_luau` calls** for the whole Studio session.
  After changing a module, delete and recreate it (or re-import) before testing.
- **Studio silently switches between open windows/places.** Assert the place
  (name, a marker instance) before every write.

## Seeing what you built
- **`capture_screenshot`:**
  - It returns a **2x retina** image; halve its pixels for click coordinates.
  - It shows ScreenGuis in a solo playtest, but **never BillboardGuis**. Verify
    those by properties instead.
  - In some playtests it comes back solid magenta. Fall back to edit mode or a
    property sweep.
- **The edit camera reverts a CFrame-only move.** Set `cam.Focus` as well, wait
  about 0.4 s, and check with a centre raycast before trusting a screenshot.
- **An unfocused Studio window runs at 15 fps.** Timing measured then is wrong.
- **Hidden panes / background tabs pause animation frames** (browser previews).

## Input and GUI
- **`simulate_mouse_input` needs GUI y + 58** (the GUI inset) to hit a
  GuiButton. With an IgnoreGuiInset root, `AbsolutePosition` is already in that
  space. `MouseEnter` and `MouseLeave` never fire from synthetic input.
- **UIStroke now scales with an ancestor UIScale.** Set its thickness in design
  units.
- **ScrollingFrame rows sized in Scale + AutomaticCanvasSize define each other**
  and collapse or explode. Use pixel row heights from the list's AbsoluteSize.
- **Clearing children with a loop also destroys the UIScale.** Skip it.
- **`Font.fromEnum(Enum.Font.Arcade)` is Press Start 2P.**

## World and runtime
- **Assets you lack permission for render as nothing**, with no error (meshes,
  images, audio). Probe them with
  `AssetService:CreateEditableImageAsync(Content.fromAssetId(id))` or
  `CreateMeshPartAsync` in a pcall.
- **Map reorganisations break code silently:**
  - Scans of `workspace:GetChildren()` find nothing once content moves into
    folders.
  - `WaitForChild` on a container that moved yields forever.
  - Discover content through one shared module, and `warn` on empty results.
- **`Part.Size` is not world extent** for rotated Blender meshes. Use
  RightVector, UpVector and LookVector, or `GetBoundingBox`.
- **Under StreamingEnabled, `GetInstanceAddedSignal(tag)` never fires** for
  instances that stream in already tagged. Rebuild tag caches on a timer.
- **`workspace.StreamingEnabled` can only be set in edit mode** (with
  `set_properties`). A script that sets it dies.
- **Z-fighting comes from exactly coplanar faces.** A 0.001-stud gap renders
  clean even 1,500 studs away. Detect at 0.005 and fix with a 0.01 offset.
- **EditableMesh content is not saved with the place.** Store a recipe or the
  data and re-bake at runtime (`editable-mesh` / MeshKit pattern). Published
  games need "Allow Mesh & Image APIs" turned on.
- **`RunService.PreSimulation` doesn't fire in edit mode.**
- **EditableMesh MeshParts made on the server render as plain boxes for
  players, and in a Studio playtest the server and client share ONE
  EditableMesh memory budget.** So the server builds plain boxes from baked
  bounds and each client covers them with shared-mesh clones
  (`references/meshlab.md`). Never build EditableMesh on the server; never
  ApplyMesh per part.
- **R15 rigs from `CreateHumanoidModelFromDescription` use AnimationConstraint
  joints**: C0 is read-only, pose with `.Transform`, ragdoll by disabling
  them, and limbs don't move in edit mode.

## Studio processes
- **`manage_instance launch source=baseplate` has hung on macOS:** stray
  `RobloxStudio --task` processes survive SIGTERM and blind the real Studio.
  - On macOS, ask the developer to use File > New instead.
  - If screenshots suddenly fail, `kill -9` the strays.
  - A Studio stuck in a "playtest transition" needs a restart, and that loses
    unsaved work, so ask first.

## Uploads and keys
- **The `robloxstudio` server's `upload_asset` may have no auth configured.**
  Upload images with the built-in server's `mcp__Roblox_Studio__upload_image`:
  - it takes http URLs only, so serve the folder with
    `python3 -m http.server --bind 127.0.0.1`;
  - it needs `studio_id` from `list_roblox_studios`;
  - it takes a batch in one call.
  - Pack icons into one sprite sheet to save uploads.
- **Keep the Open Cloud key outside the project** (a key file outside the
  project, or an environment variable). Read it inside the
  command and never print it. Check its scopes: a key made only for developer
  products can't do anything else; a general key needs Assets,
  Universe-places, Data Stores and Messaging.
