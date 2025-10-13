using Godot;
using System.Collections.Generic;
using System.Linq;

[GlobalClass]
public partial class BVHNode : RefCounted
{
    public Aabb Bounds { get; set; }
    public BVHNode Left { get; set; }
    public BVHNode Right { get; set; }
    public int[] Indices { get; set; }

    /// <summary>
    /// Creates a leaf node containing the specified indices
    /// </summary>
    public static BVHNode CreateLeaf(int[] indices)
    {
        return new BVHNode { Indices = indices };
    }

    /// <summary>
    /// Creates an internal node with bounds and child nodes
    /// </summary>
    public static BVHNode CreateInternal(Aabb bounds, BVHNode left, BVHNode right)
    {
        return new BVHNode
        {
            Bounds = bounds,
            Left = left,
            Right = right
        };
    }

    /// <summary>
    /// Builds a complete BVH from position array
    /// </summary>
    public static BVHNode BuildBVH(Vector3[] positions)
    {
        var indices = new int[positions.Length];
        for (int i = 0; i < positions.Length; i++)
            indices[i] = i;

        return BuildBVHRecursive(positions, indices);
    }

    /// <summary>
    /// Recursively builds the BVH tree structure
    /// </summary>
    private static BVHNode BuildBVHRecursive(Vector3[] positions, int[] indices)
    {
        if (indices.Length <= 5)
            return CreateLeaf(indices);

        var bounds = ComputeBoundingBox(positions, indices);
        var axis = ChooseSplitAxis(bounds);
        var splitPoint = CalculateSplitPoint(positions, indices, axis);

        var leftIndices = new List<int>();
        var rightIndices = new List<int>();

        foreach (var idx in indices)
        {
            if (positions[idx][axis] < splitPoint[axis])
                leftIndices.Add(idx);
            else
                rightIndices.Add(idx);
        }

        if (leftIndices.Count == 0)
        {
            leftIndices.Add(indices[0]);
            rightIndices.RemoveAt(rightIndices.Count - 1);
        }

        if (rightIndices.Count == 0)
        {
            rightIndices.Add(indices[indices.Length - 1]);
            leftIndices.RemoveAt(leftIndices.Count - 1);
        }

        var leftChild = BuildBVHRecursive(positions, leftIndices.ToArray());
        var rightChild = BuildBVHRecursive(positions, rightIndices.ToArray());

        return CreateInternal(bounds, leftChild, rightChild);
    }

    /// <summary>
    /// Computes the bounding box for a set of positions
    /// </summary>
    private static Aabb ComputeBoundingBox(Vector3[] positions, int[] indices)
    {
        if (indices.Length == 0)
            return new Aabb();

        var result = new Aabb(positions[indices[0]], Vector3.Zero);

        foreach (var idx in indices)
            result = result.Expand(positions[idx]);

        return result;
    }

    /// <summary>
    /// Chooses the best axis to split the bounding box
    /// </summary>
    private static int ChooseSplitAxis(Aabb bounds)
    {
        var size = bounds.Size;

        if (size.X >= size.Y && size.X >= size.Z)
            return 0;

        if (size.Y >= size.Z)
            return 1;

        return 2;
    }

    /// <summary>
    /// Calculates the split point along the specified axis
    /// </summary>
    private static Vector3 CalculateSplitPoint(Vector3[] positions, int[] indices, int axis)
    {
        if (indices.Length == 0)
            return Vector3.Zero;

        float sum = 0.0f;
        foreach (var idx in indices)
            sum += positions[idx][axis];

        var median = sum / indices.Length;
        var splitPoint = Vector3.Zero;
        splitPoint[axis] = median;

        return splitPoint;
    }

    /// <summary>
    /// Recursively clears all nodes in the tree
    /// </summary>
    public void ClearRecursive()
    {
        Indices = null;

        if (Left == null && Right == null)
            return;

        Left?.ClearRecursive();
        Right?.ClearRecursive();
        Left = null;
        Right = null;
    }

    /// <summary>
    /// Queries the BVH for all indices within the specified bounds
    /// </summary>
    public int[] Query(Vector3[] positions, Aabb checkBounds, int excludeIndex)
    {
        var result = new List<int>();
        QueryRecursiveInternal(positions, checkBounds, excludeIndex, result);
        return result.ToArray();
    }

    /// <summary>
    /// Internal recursive query implementation
    /// </summary>
    private void QueryRecursiveInternal(
        Vector3[] positions,
        Aabb checkBounds,
        int excludeIndex,
        List<int> result)
    {
        if (Left == null && Right == null)
        {
            if (Indices == null)
                return;

            foreach (var idx in Indices)
            {
                if (idx == excludeIndex)
                    continue;
                if (!checkBounds.HasPoint(positions[idx]))
                    continue;
                result.Add(idx);
            }
            return;
        }

        if (!Bounds.Intersects(checkBounds))
            return;

        Left?.QueryRecursiveInternal(positions, checkBounds, excludeIndex, result);
        Right?.QueryRecursiveInternal(positions, checkBounds, excludeIndex, result);
    }
}
