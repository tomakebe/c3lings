# Chapter 08. The Scene: Transform Hierarchies and Spatial Structures

> Chapter exercises: `e0801_transform_hierarchy` … `e0806_scene_culling`.
> Assumes you have completed chapters 03 (handles, flat arrays), 04 (matrices and
> transforms) and 05 (ECS).

"Scene" is one of the most overloaded words in engine development. In the Unity editor it is a
`.unity` file, in Godot it is a tree of `Node`s, in Unreal it is a `UWorld` with levels and actors, and in a renderer it is a
list of visible meshes. In this chapter we care about two things that almost every
engine needs, regardless of its philosophy:

1. **The transform hierarchy.** A wheel is attached to a car, the car to a platform, a pistol
   to a hand bone. Objects are specified *relative* to their parent, but the rest of the engine needs
   *world* coordinates.
2. **Spatial queries.** "What does the camera see?", "Who is inside the blast radius?", "What can I
   collide with?". Answering these by brute-forcing over every object stops being viable at a few thousand
   entities.

These are two different problems with different data structures, and one of the classic design
mistakes is trying to solve both with a single tree. We will come back to this.

---

## 1. Local and world

Each node stores a **local** transform: position, rotation and scale relative to its
parent. The **world** transform is the composition of all ancestors:

```
world(root) = local(root)
world(n)    = world(parent(n)) * local(n)
            = local(root) * ... * local(parent) * local(n)
```

Why not just store world transforms directly? Because artists and gameplay think locally: "the turret
is rotated 30° relative to the hull", "the sword is in the hand". If you store only world, then when
the hull rotates you have to manually recompute every nested object, which means implementing a hierarchy
anyway, just in the worst possible place. So engines store **both** representations:
local is the source of truth, world is a cache, a derived value.

```
          city (local: translate 100,0)
           |
         car  (local: translate 10,0; rotate 90)
         /  \
    wheel   turret (local: translate 0,1; rotate -45)
                \
               barrel (local: translate 3,0)

  world(barrel) = L(city) * L(car) * L(turret) * L(barrel)
```

## 2. How to store a transform

The options, from simple to complex:

| Representation | Pros | Cons |
|---|---|---|
| 4x4 matrix (3x3 in 2D) | composition is a single multiply, GPU-ready | 64 bytes, cannot be interpolated, accumulates error (skew) |
| 3x4 affine (2x3 in 2D) | 25% smaller, the bottom row is always (0,0,0,1) | still not interpolable |
| TRS: translation + quaternion + scale | 40 bytes, interpolable (animation!), easy to edit | composition is more expensive, non-uniform scale + rotation on the parent breaks TRS |

In practice: the **local** transform is stored as TRS (animation, the editor and
gameplay all manipulate it), and the **world** transform as an affine matrix (consumed by rendering and physics). Unreal stores
`FTransform` (quaternion + translation + 3D scale) for both local and world; Unity stores
TRS in `Transform` plus a cached `localToWorldMatrix`; Bitsquid/Stingray's `SceneGraph`
kept local as a `Matrix4x4` or a TRS "Pose" and world as a matrix.

A separate subtlety is **non-uniform scale**. If the parent is stretched 2x along X and the
child is rotated 45°, the child's world matrix contains shear, which cannot be
expressed in TRS. Unreal and Unity both openly warn in their documentation that decomposing
the world matrix back into TRS is approximate in this case. Many engines (Godot in 2D among them)
simply forbid or discourage non-uniform scale on parents with rotated
children. The approach for your own engine: world transforms are matrices, and an API like
`get_world_rotation()` honestly documents that it is inaccurate in the presence of shear.

## 3. Multiplication order

This is the single most common bug in hierarchies. For column vectors (`p' = M * p`, the convention of OpenGL,
most textbooks, and this course), `A * B` means "first B, then A". The world
matrix is `parent * local`: the point is first transformed from the child's space into
the parent's space (local), then further up.

```c3
// self * c : first c, then self.
fn Affine2 Affine2.mul(self, Affine2 c) { ... }

Affine2 world = world_of_parent.mul(local);   // correct
Affine2 wrong = local.mul(world_of_parent);   // "almost works"
```

The treachery is in the word "almost": if the parent has no rotation or scale, both variants produce
the same translation. The bug surfaces a month later, when an artist rotates the root object.
That is why the tests in `e0801` deliberately rotate and scale the parent. The DirectX convention
(row vectors, `p' = p * M`) reverses the order: there, `world = local * parent`. Pick
one convention for the entire engine and write it down in a comment next to the matrix type.

The naive `world_matrix(i)` implementation from `e0801` walks up the parents and multiplies:
O(depth) per query. With 10,000 objects, depth 8, and three systems querying each object per frame,
that is 240,000 matrix multiplications, most of them redundant. We need a cache.

## 4. Dirty flags: lazy recomputation

The "Dirty Flag" pattern is described in detail by Nystrom (Game Programming Patterns, the
"Dirty Flag" chapter), and the transform hierarchy is its canonical example. The idea: world is a cache,
the cache is marked stale when its source changes and is recomputed on read.

```
set_local(i):  local[i] = v; mark_dirty(i)       // cheap, computes nothing
get_world(i):  if dirty[i]:
                   world[i] = get_world(parent) * local[i]   // recursively cleans ancestors
                   dirty[i] = false
               return world[i]
```

The flag must propagate **downward**: when a parent moves, the world transforms of all its
descendants become stale. Hence the key invariant:

> if a node is dirty, all of its descendants are dirty too.

Thanks to it, `mark_dirty` can stop at an already-dirty node: everything below is already marked. Without
this optimization, gameplay code that moves a character's root five times a frame walks
the entire skeleton tree five times. With it, once plus four flag checks.

What we gain:

* **Laziness.** If nobody read an object during the frame (it is off-screen, its physics is asleep), its world
  transform is never recomputed at all.
* **Change coalescing.** N changes before a read cost a single recomputation.

What it costs:

* **Branches and unpredictable access.** Every `get_world` is a flag check, possibly
  a recursion upward. Readers are scattered across the frame, and the CPU cache is cold.
* **Multithreading complexity.** `get_world` is a *write* (it updates the cache). Two threads
  reading the world transform of the same object create a race. That is why Unity, before DOTS, required
  `Transform` to be accessed only from the main thread; Unreal updates `ComponentToWorld` in
  `UpdateComponentToWorld` on the game thread and then copies it to the render thread.
* **Stale caches that bypass the API.** If someone writes `local` directly without calling
  `mark_dirty`, the bug will show up intermittently. The field must be private and modified only
  through a function (in C3, via `@private` or module boundaries).

A variant many engines use: **dirty flag + an explicit update phase**. Changes
only mark nodes (and, for example, push the root of the changed subtree onto a list), and at a
well-defined point in the frame (after gameplay, before physics/rendering) a single function updates
all dirty subtrees in one go. Reads at any other time just return the cache, which may be
a frame old, and this must be documented. Unity does exactly this in
`TransformHierarchy` (there is a `TransformChangeDispatch` that collects changed
hierarchies), Godot via `notification(NOTIFICATION_TRANSFORM_CHANGED)` and a deferred
update queue.

## 5. Flat hierarchy: "parent before child"

Trees of objects with `children` pointers are natural for an editor and terrible for the
cache. Every node is a separate allocation, traversal is a series of jumps through memory, and a `std::vector<Node*>`
of children is yet another indirection.

Bitsquid/Stingray (Niklas Frykholm, the "Building a Data-Oriented Entity System" series and the post
on the scene graph), later Our Machinery, bone hierarchies in every animation system, and Unity DOTS
(`LocalToWorldSystem`) do it differently: the hierarchy is **a set of parallel arrays**
(SoA), sorted so that **a parent always comes before its child**:

```
 index:   0      1      2      3      4      5
 parent: -1     -1      0      0      1      3
 local:  L0     L1     L2     L3     L4     L5
 world:  W0     W1     W2     W3     W4     W5

 for i in 0..n:
     world[i] = parent[i] < 0 ? local[i] : world[parent[i]] * local[i]
```

One linear pass, zero recursion, zero stack, predictable branches, arrays read
sequentially (except `world[parent[i]]`, but the parent is almost always "not far behind" and
already in cache). For a 100-bone skeleton this is tens of nanoseconds for the whole thing. Dirty
flags can be added too: skip nodes whose own flag and whose parent's flag are clear; within a single pass the flag
propagates by itself: `dirty[i] |= dirty[parent[i]]`.

The price is **maintaining the order**. When nodes are loaded in arbitrary order or
change parents, the arrays have to be permuted. The simplest strategy, used in `e0803`, is a stable
sort by depth. The single most important thing about any permutation: **all index-based references
become invalid**. You need a `remap[old] = new` table through which `parent` is renumbered,
along with anything outside that stored indices. That is why external code must never hold
a "raw" hierarchy node index: only a handle (chapter 03), which is mapped to the current index through an
indirection table. This is exactly how `SceneGraph` in Bitsquid works:
the user holds an `Instance`, and the internal array is free to be reordered.

How often does reordering happen? In a game, rarely: reparenting (picking up
an item, getting into a car) is a handful of events per frame, not thousands. So paying
O(n) for a re-sort on reparent is usually acceptable, and in critical cases you can
move the entire subtree to the end of the array (it stays "after" the new parent, as long as
the parent comes earlier) without a full sort.

## 6. DFS order and contiguous subtrees

A special case of "parent before child" ordering is **depth-first (preorder) traversal**. It has
a bonus: a node's entire subtree lies in the array **contiguously**:

```
          A
        /   \
       B     E
      / \     \
     C   D     F

 index:        0  1  2  3  4  5
 node:         A  B  C  D  E  F
 subtree_end:  6  4  3  4  6  6      subtree of node i = [i, subtree_end[i])
```

What this buys you:

* **Skipping a subtree** in O(1): `i = subtree_end[i]`. This is the basis of hierarchical
  culling in `e0806`.
* **Removing/moving a subtree** is a `memmove` of one contiguous range.
* **A reverse pass** (`i` from n-1 down to 0) processes children before parents, ideal for
  "bottom-up aggregates": subtree bounds (bounding volume), total mass, an "is anything
  in this subtree visible" flag.

This is exactly how hierarchies are stored in formats optimized for load speed (for example,
skeletons in glTF after import, or scenes in engines' cooked formats): after "baking", the scene
is loaded as a single block and is immediately ready for a linear update.

## 7. Scene graph vs. flat structures

In the '90s and 2000s the "scene graph" (OpenInventor, OpenSceneGraph, Ogre, Java3D)
was the universal answer: a single tree whose nodes are transforms, groups, materials,
LOD switches, geometry. The renderer walked the tree recursively, accumulating state and
culling subtrees by their bounding sphere.

Why engines moved away from this (Tom Forsyth, "Scene Graphs — just say no"; DICE and
Bitsquid talks on data-oriented design):

* **One tree, several incompatible hierarchies.** The transform hierarchy (sword in
  hand) does not match the spatial one (the sword is next to a wall, not next to the character's
  root), nor the render-state hierarchy (all objects sharing a material), nor the
  logical one (team, squad). A tree that is optimal for one is bad for the others.
* **Recursive traversal of objects with virtual functions** is the worst possible memory access pattern.
* **Poor parallelism**: a tree with shared traversal state is hard to split across threads.

The modern approach is **separation of concerns**:

```
  transform hierarchy          ->  flat SoA arrays, linear pass (e0803/e0806)
  spatial index                ->  grid / quadtree / BVH, separate structure (e0804/e0805)
  rendering                     ->  flat list of visible objects -> command buffer (chapter 09)
  logic                         ->  ECS queries (chapter 05)
```

That said, **the tree in the editor** has not gone anywhere: Godot is built entirely around the `Node` tree,
Unity has `GameObject`/`Transform`, Unreal has `USceneComponent` with attach parents. But
that is a convenient *model for humans*; internally (especially in Unity DOTS, in Unreal's renderer
`FScene`, in Godot 4's servers, `RenderingServer` and `PhysicsServer`) the data is laid out
flat and processed in batches.

## 8. Spatial structures

Now the second problem. We have N objects with bounding boxes and need to answer queries quickly:
"intersection with a region", "nearest neighbors", "ray". The general idea is to partition either space or
the set of objects so that most of it can be discarded with a single check.

### 8.1 Uniform grid

The world is divided into cells of size `CELL`; an object lands in a cell (or cells, if it is
large) based on its coordinates. A query only visits the cells it touches.

```
  +----+----+----+----+
  |  . |    |  ..|    |       query [###] touches 4 cells,
  +----+----+-[##+##]-+       we only check objects in those
  |    |  . | [##+##] |
  +----+----+----+----+
```

Pros: O(1) insertion, trivial to implement, excellent constant factor, easy to parallelize.
Cons: one cell size for everything. Small cells mean lots of empty memory and large objects
spanning dozens of cells; large cells mean crowds in a single cell.

Storage. "A list in every cell" means thousands of allocations. In `e0804` we build a **compact
grid via counting sort** (this is how particle-physics broadphases, spatial hashes in
SPH fluids, and tiled light culling in Forward+ on the GPU are built):

```
  1) count[cell]++ for each object
  2) start = exclusive prefix sum(count)
  3) entries[start[cell] + k] = id
```

Rebuilding is O(N + cells) per frame, zero allocations, and each cell's contents are contiguous in memory.
This is often faster than incrementally moving objects between cells, especially when
most objects move (particles, crowds).

If the world is infinite or sparse, use a **spatial hash**: `hash(cx, cy) % TABLE`
instead of `cy * W + cx`. Hash collisions produce extra candidates but not errors (the exact check
is performed anyway).

### 8.2 Quadtree and octree

A quadtree (2D) and an octree (3D) adapt to density: a node splits into 4 (8)
quadrants when it holds too many objects (`e0805`). Where it is empty the tree is shallow; where it is
dense, deep.

Practical details that matter more than the theory:

* **Nodes in a pool with indices**, not `new Node` with pointers; with 4 children stored contiguously it is enough
  to store `first_child`. This is at once more compact, more cache-friendly, and trivially serializable.
* **Depth limit.** Otherwise several objects at the same point would split the tree
  forever. A leaf at maximum depth simply stores any number of objects.
* **Objects with extent.** A point is easy to put into a single leaf. An object with an AABB may straddle
  quadrant boundaries. Options: put it into the smallest node that fully contains it (this is
  what a "loose" tree does, but an object on a root boundary gets stuck in the root); put it into every
  leaf it overlaps (duplicates, results need deduplication); a **loose octree**
  (Ulrich, Game Programming Gems 1): nodes with bounds "inflated" by 2x, so that any object
  no larger than a node fits into exactly one node at its level.
* **Moving objects** are the main pain point of trees: remove and re-insert, possibly
  merging emptied nodes. For dynamic content a grid or a BVH with "fat" AABBs is the more common choice.

Octrees are a good fit for static geometry, voxels (SVO), and sparse lighting fields.

### 8.3 BVH: bounding volume hierarchy

Grids and quadtrees partition **space**. A BVH partitions **the set of objects**: each node
stores an AABB enclosing all of its descendants; the leaves are objects. Each object is in exactly one leaf,
there are no duplicates; nodes may overlap.

```
            [ AABB of all ]
            /           \
     [AABB A,B]       [AABB C,D,E]
      /     \          /        \
     A       B       C       [AABB D,E]
                               /    \
                              D      E
```

Where it is used:

* **Ray tracing**: BVH is the de facto standard (DXR/Vulkan RT build one in the driver,
  Embree on the CPU). Construction uses SAH (surface area heuristic).
* **Dynamic broadphase**: Box2D's `b2DynamicTree`, Bullet's `btDbvt`: an incremental AABB
  tree with fat AABBs: an object recreates its leaf only when it moves outside the margin.
  Insertion picks a sibling that minimizes area growth, and the tree is balanced via rotations.
* **Static culling**: a scene BVH built offline.

The transform hierarchy with subtree bounds from `e0806` is a special case of a BVH, where
the tree structure is defined not by space but by the scene's logic. It works as long as the logical
hierarchy is spatially compact (a district's buildings are next to each other). If a character runs around
the whole map and its parent is the "level root", the root's bounds are huge and cull
nothing. That is why engines build a separate spatial index instead of relying on the
transform tree.

### 8.4 How to choose

| Structure | Insert/move | Query | Non-uniform density | Where |
|---|---|---|---|---|
| Brute force (SIMD) | O(1) | O(N) | doesn't matter | up to ~1–5k objects this is genuinely fast! |
| Grid / hash | O(1) | O(cells + candidates) | poor | particles, crowds, 2D games, broadphase |
| Quadtree/octree | O(log N) | O(log N + k) | good | static geometry, large open worlds |
| BVH (dynamic) | O(log N) | O(log N + k) | good | physics, rays, culling |

Don't forget the first row. Brute-forcing an SoA array of AABBs with SIMD checks 4–8 boxes per
instruction, with no cache misses and no branches. Frostbite (Daniel Collin's talk, "Culling the
Battlefield", GDC 2011) replaced a hierarchical culling structure with a **linear scan**
of flat arrays of spheres, bucketed into the cells of a coarse grid, and became several times faster. Measure
first.

## 9. Culling

Culling is discarding objects that definitely will not affect the image before they are sent to the
GPU. The kinds, from cheapest to most expensive:

1. **Frustum culling**: the object is outside the camera's view frustum. In 3D the frustum is defined by
   six planes; an AABB is tested against each (the "nearest/farthest vertex" test or
   "center + projection of half-extents onto the normal"). In 2D and in our exercises it is an intersection with
   the view rectangle.
2. **Distance / detail culling**: objects that are too far away or too tiny on screen (screen size
   culling). Often combined with LOD selection.
3. **Occlusion culling**: the object is hidden behind others. Offline: PVS (potentially visible sets):
   id Tech 1–3 partitioned the level with a BSP tree and precomputed, for each leaf, the visible
   leaves; portals (Unreal 1, Doom 3) for indoor levels. Online: software rasterization
   of occluders into a small depth buffer (Frostbite, Intel Masked Occlusion Culling), Hi-Z
   on the GPU using the previous frame's data, GPU-driven culling in compute (Unreal Nanite,
   "two-pass occlusion culling").

The hierarchical culling in `e0806` illustrates the general principle: check a group's bounds,
and if they miss, discard the whole group with a single check. Pay attention to the exercise's
output: when everything is visible, the hierarchy performs *more* checks than brute force (the extra
group checks). That is an acceptable price; the hierarchy wins when only a small fraction of the
scene is visible, which in games with large worlds is almost always the case.

The result of culling is a **flat list of visible objects** (indices or handles),
which is then turned into render commands with sort keys (chapter 09). In a
multithreaded engine, culling is one of the first tasks to be parallelized: the object array
is split into chunks, each thread writes its own list, and the lists are concatenated.

## 10. Pitfalls

* **Matrix multiplication order** (section 3). Test hierarchies with parent rotation and
  scale.
* **Dangling pointers into dynamic array elements.** `QNode* n = &nodes[i];` followed by
  `nodes.push(...)`, and `n` may now point into freed memory. In `e0805` this is the trap
  in `split`. Take a copy or an index.
* **Indices after permutation.** Any sort of the hierarchy invalidates external indices.
  Expose only handles.
* **Updates mid-frame.** If physics reads world before the hierarchy update phase, and
  rendering reads it after, they see different worlds. Define an explicit frame phase order (chapter 01) and
  a point at which world transforms are consistent.
* **Float precision at large coordinates.** At 10 km from the origin
  float gives a step of about a millimeter, at 100 km centimeters: camera and
  animation jitter. Solutions: origin shifting (floating origin, Unity/KSP), camera-relative
  coordinates for rendering, double for world positions (Unreal 5 Large World
  Coordinates, Star Citizen).
* **Negative scale** flips triangle orientation (winding): the renderer must
  switch face culling based on the sign of the world matrix's determinant.
* **Grid cells that are too small** for large objects: an object in 100 cells means 100 entries
  and duplicates in queries.
* **A quadtree without a depth limit** recurses forever on coincident coordinates.

## 11. How real engines do it

* **Unreal Engine.** `USceneComponent` stores `RelativeLocation/Rotation/Scale` and a cached
  `ComponentToWorld` (`FTransform`); an attach hierarchy of components; `UpdateComponentToWorld`
  recursively updates children on change (not lazily, but with flags for skipping). The renderer
  lives in a separate `FScene` with flat arrays of primitives (`FPrimitiveSceneInfo`);
  culling is a parallel scan over bounds + occlusion queries/Hi-Z, and in UE5, Nanite with
  a cluster hierarchy on the GPU.
* **Unity.** `Transform` with a hierarchy; internally, `TransformHierarchy` stores the hierarchy as
  flat arrays, separate for each root (which is why the advice "keep deep
  hierarchies under different roots" affects update parallelism via
  `TransformAccessArray`). Culling: `CullingGroup`, Umbra for occlusion.
* **Godot 4.** A `Node` tree for the user; `Node3D` caches the global transform with a
  dirty flag; the rendering server keeps its own flat structures and uses
  `DynamicBVH` for culling.
* **Bitsquid/Stingray.** `SceneGraph` as flat local/world/parent arrays with
  "parent before child" ordering, `Instance` handles exposed externally; culling over flat arrays.
* **id Tech.** BSP + PVS + portals in the classic engines; in id Tech 6/7, GPU-driven rendering with cluster
  culling in compute.
* **Frostbite.** "Culling the Battlefield": coarse grid + linear SIMD scan + software
  occlusion.

## 12. Chapter exercises

| Exercise | What we do |
|---|---|
| `e0801_transform_hierarchy` | 2D affine matrices, composition, world matrix by walking up the parents |
| `e0802_dirty_flags` | lazy world recomputation, the "dirty ⇒ descendants dirty" invariant, early exit |
| `e0803_flat_hierarchy` | SoA hierarchy, a single linear pass, depth sort with remap |
| `e0804_uniform_grid` | compact grid built on counting sort, rectangle query |
| `e0805_quadtree` | quadtree on a node pool, intrusive point lists, split, query |
| `e0806_scene_culling` | DFS order, subtree bounds via a reverse pass, hierarchical culling |

## Self-check questions

1. Why do engines store both local and world transforms? Which one is the source of truth?
2. What is the difference between `parent * local` and `local * parent` in the column-vector convention? Why does
   the bug go unnoticed as long as the parent has no rotation?
3. State the dirty-flag invariant for a hierarchy. What breaks if `mark_dirty`
   exits early, and `get_world` on a child clears its ancestors' flags without touching its descendants?
4. Why is `get_world` with a lazy cache a problem for multithreading? How does an explicit
   update phase solve it?
5. Which invariant makes it possible to compute world transforms in a single loop without recursion?
   What must be done with references after nodes are permuted?
6. How is DFS preorder better than plain "parent before child"? How do you skip a
   subtree in O(1)?
7. Why does the pass that computes subtree bounds start from the end of the array?
8. Describe a compact grid built on counting sort. Why is it rebuilt from scratch every
   frame rather than updated incrementally?
9. When is a quadtree better than a grid? How do you store objects with extent in it, rather than points?
10. How does a BVH fundamentally differ from an octree? Why do physics engines
    use a dynamic AABB tree with "fat" boxes for the broadphase?
11. Why is a transform hierarchy a bad spatial index?
12. When is a linear scan faster than any hierarchical structure? What did
    Frostbite do in "Culling the Battlefield"?

## Further reading

* Jason Gregory, *Game Engine Architecture* (3rd ed.): the chapters on scene graphs, spatial
  subdivision, visibility determination and game objects.
* Robert Nystrom, *Game Programming Patterns*: the "Dirty Flag" chapter (its example is precisely
  the transform hierarchy) and "Spatial Partition".
* Christer Ericson, *Real-Time Collision Detection*: chapters 6–7 (BVH, grids, trees),
  the best book on spatial structures for games.
* Tomas Akenine-Möller et al., *Real-Time Rendering* (4th ed.): chapter 19, "Acceleration
  Algorithms": culling, PVS, portals, occlusion culling, LOD.
* Niklas Frykholm, the Bitsquid blog: "Building a Data-Oriented Entity System" (the parts on
  the transform component and the scene graph), "Managing Decoupling".
* Daniel Collin, "Culling the Battlefield: Data Oriented Design in Practice" (DICE, GDC 2011).
* Tom Forsyth, "Scene Graphs — just say no" (blog).
* Thatcher Ulrich, "Loose Octrees", Game Programming Gems 1.
* Erin Catto, "Dynamic Bounding Volume Hierarchies" (GDC 2019): Box2D's dynamic AABB
  tree.
* Sebastian Aaltonen, Ulrich Haar, "GPU-Driven Rendering Pipelines" (SIGGRAPH 2015):
  GPU culling.
