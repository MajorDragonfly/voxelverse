# H1: nominal Godot 4.6.3 draw path with render_loop_enabled=false

Read-only source review, 2026-10-08. No engine invocation, viewport change, product mutation, camera QA mutation, guard change or original capture suppression.

## Source and measured-binary boundary

Official upstream tag 4.6.3-stable resolves directly to commit 35e80b3a8822a9df9be390814b62f44c0a9c69e8, tree 499fa231ee5d21878988a4a9cb881749def3946d: the /git/ref/tags endpoint reports object.type=commit. This is a lightweight tag, not an annotated tag SHA mistaken for its peeled commit. /git/tags/35e80b3a8822a9df9be390814b62f44c0a9c69e8 returns404; /git/commits/35e80b3a8822a9df9be390814b62f44c0a9c69e8 returns a valid verified signed commit.

The Forward owner reports measured binary SHA256 f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3, header4.6.3.stable.official.7d41c59c4, and ELF full40 build literal7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3 at offset81750312. Official /commits/FULLSHA returns422 (No commit found). Therefore these nominal upstream semantics do not establish exact source identity for that measured binary. The invalid-ref file-fetch responses were excluded from source binding. All nominal source blob SHAs below were independently matched through the official commit's Git tree; see source_bindings.json and API JSON files.

## Nominal automatic draw gate

main/main.cpp4977–4998 calls RenderingServer::sync unconditionally, then computes pending from RenderingDevice::has_pending_resources_for_processing. wants_present is window/additional-output availability AND render_loop_enabled. The outer draw gate is wants_present OR pending. With the flagfalse and pendingtrue, that automatic branch can call draw(false), incrementing Engine frames_drawn. force_redraw_requested is ORed only inside the outer gate; it does not independently open a closed gate. Low-processor-usage mode adds has_changed gating.

The public property description in pinned doc/classes/RenderingServer.xml4510–4511 states “disables rendering completely” and mentions force_draw. That description does not document the pending-RD automatic branch. Precisely, the nominal implementation uses the flag to suppress wants_present; it does not forbid draw(false) for pending resources.

RenderingServer::force_draw is bound directly to RenderingServer::draw (rendering_server.cpp3604) and bypasses this property, but that binding does not itself increment Engine frames_drawn. This distinction makes the observed102 matching draw signals and Engine frame increments consistent with the nominal automatic Main path; it is not proof that this exact measured binary took that branch.

## Concrete pending-resource owner and chain

rendering_device.h1629 stores private uint32_t frames_pending_resources_for_processing; the public native getter1632 tests nonzero. It is not an exposed GDScript/ClassDB query in the inspected binding implementation.

In rendering_device.cpp, free_rid6300–6305 calls _free_dependencies then _free_internal. _free_internal6307–6427 queues owned resources on the current frame's retirement lists and sets the counter to frames.size() at6426. That is the only literal counter assignment in this nominal implementation; even the invalid-ID branch reaches the assignment. Repeated calls can replenish the retirement counter. _free_pending_resources6568–6648 retires ring-frame lists and decrements the counter at6645–6646. _begin_frame calls this at6701. swap_buffers6533–6546 executes the frame, advances the ring and begins the next frame even when p_present=false; compositor_rd.cpp120–121 passes that flag through. _execute_frame6807–6832 always executes chained commands; only presentation is conditional.

This gives a concrete hypothesis: repeated native resource-retirement requests can keep the automatic pending gate open. The observed Voxelverse resource producer and actual counter values remain unmeasured; no shader, terrain, driver or GPU cause is claimed.

## What the accepted draw does

RenderingServerDefault::draw436–446 emits frame_pre_draw and then queues/calls _draw. _draw69–127 runs updates, draw_viewports and rasterizer end_frame even with false presentation. renderer_viewport.cpp769–821 selects enabled/visible viewports; standard mono _draw_viewport is called at894 independent of p_swap_buffers. Only final screen blit945–949 is gated by p_swap_buffers. Window::can_draw598–607 and SubViewport::set_update_mode5475–5478 influence availability/selection; they do not by themselves reopen Main's global gate.

Post-draw signal occurs in _run_post_draw_steps222 after frame-drawn callbacks; _draw124 may defer those steps from the render thread. Thus accumulated pre→post time includes render work, command queue/main-thread scheduling and callbacks. It is not a pure GPU duration.

## Sync and readback boundary

RenderingServerDefault::sync428–434 flushes/synchronizes the command queue; it does not explicitly call draw or emit the draw signals. RenderingDevice::sync6559–6565 applies to local devices and is a different operation.

ViewportTexture::get_image180–185 → RenderingServer texture_2d_get → TextureStorage::texture_2d_get1494–1503 → RenderingDevice::texture_get_data2023 onward. The GPU copy path calls _flush_and_stall_for_all_frames at2087; that helper6928–6937 stalls, executes a frame with false presentation and starts/waits a frame. It does not itself call RenderingServer::draw or emit pre/post. Readback can add synchronization/submission cost but is not, alone, a direct explanation of the observed matching RS signal pairs and Engine frame increments.

## Narrow next opt-in instrumentation, preserving all original draws

First resolve the measured-binary source/symbol binding before attributing any native field values to this nominal code. Then passively record:
1. At Main's gate4977–4998: monotonic timestamp, wants_present, pending, force_redraw_requested, low-processor mode/has_changed, and the actual p_present argument.
2. At RD::_free_internal counter reset6426: monotonic timestamp, native thread, RID and owned resource class, caller/backtrace, old/new counter and ring size.
3. At retirement decrement6645–6646: timestamp, ring frame and old/new counter.

The first record distinguishes pending-driven automatic draws from explicit force_draw. The second identifies the replenishing producer; the third confirms drain behavior. Do not disable viewports, change the flag timing, suppress draws or change original guards. A GDScript free-RID log can only give correlation; it cannot substitute for the native pending counter. If native symbols/addresses cannot be reliably bound to the measured binary, retain the source-binding limit rather than inventing a getter or cause.

## Evidence

source_bindings.json maps every exact unmodified source excerpt to its pinned URL, original line range, source Git blob and independently verified Git-tree path. API tag/commit replies and the exact422/404 limits are included. This directory contains only small text excerpts and metadata, not a new engine or source checkout.

