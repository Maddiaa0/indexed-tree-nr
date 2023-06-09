use dep::std::hash::pedersen;
use dep::std::merkle::check_membership;
use dep::std::merkle::compute_root_from_leaf;

use crate::nullifier_leaf::NullifierLeaf;

// using size 4 for the meantime
// Returns the new root of the created subtree
fn batch_insert_check(
    new_nullifiers: [Field; 4],
    low_nullifier_leaf_preimages: [NullifierLeaf; 4],
    low_nullifier_leaf_sibling_paths: [[Field; 4]; 4], // 4 deep tree, 4 inserting to test
    low_nullifier_leaf_indexes: [Field; 4],
    current_root: Field,
    next_available_index: Field,
    subtree_insertion_sibling_path: [Field; 2],
) -> Field{
    
    // Our set of nullifier leaves to be in our pending insertion set.
    let mut pending_insertion_subtree: [NullifierLeaf; 4] = [NullifierLeaf::empty();4];

    // The root can be updatable
    let mut root = current_root;

    // Keep track of the tree index we are inserting into
    let mut next_insertion_index = next_available_index;

    for i in 0..new_nullifiers.len() {
        let new_nullifier = new_nullifiers[i];
        // Mutable in order to update the leaf's pointers
        let mut low_nullifier_preimage = low_nullifier_leaf_preimages[i];
        let low_nullifier_sibling_path = low_nullifier_leaf_sibling_paths[i];
        let low_nullifier_index = low_nullifier_leaf_indexes[i];

        // We must look within our pending subtree to find the low nullifier
        if (low_nullifier_preimage.is_empty()) {
            let mut matched: bool = false;

            for j in 0..i {
                let mut pending_leaf: NullifierLeaf = pending_insertion_subtree[j];
                // TODO: might need to put the break here
                if (pending_leaf.value != 0) & !matched {

                    // Blocker - need Field level comparisons
                    let nnu64: u64 = new_nullifier as u64;
                    if ((pending_leaf.value as u64 < nnu64) & ((pending_leaf.next_value as u64 > nnu64) | (pending_leaf.next_value == 0))) {

                        matched = true;

                        // Update pointers
                        let new_nullifier_leaf = NullifierLeaf {
                            value: new_nullifier,
                            next_index: pending_leaf.next_index,
                            next_value: pending_leaf.next_value
                        };

                        // Update the pending subtree
                        pending_leaf.next_index = next_insertion_index;
                        pending_leaf.next_value = new_nullifier;

                        pending_insertion_subtree[j] = pending_leaf;
                        pending_insertion_subtree[i] = new_nullifier_leaf;
                    }
                }

            }

            // If we are unable to find a suitable low nullifier, we cannot proceed
            assert(matched);
        } else {
            // Membership check for the low nullifier
            let low_nullifier_hash = low_nullifier_preimage.hash();
            // TODO: is the hash path a sibling path or a set of pairs?
            let member = check_membership(root, low_nullifier_hash, low_nullifier_index, low_nullifier_sibling_path);
            assert(member == 1);

            // Range check the low nullifier against the new nullifier
            assert((new_nullifier as u64 < low_nullifier_preimage.next_value as u64) | (low_nullifier_preimage.next_value == 0 ));
            assert(new_nullifier as u64 > low_nullifier_preimage.value as u64);

            // Update the new nullifier pointers
            let new_nullifier_leaf = NullifierLeaf {
                value: new_nullifier,
                next_index: low_nullifier_preimage.next_index,
                next_value: low_nullifier_preimage.next_value
            };

            // Update low nullifier pointers
            low_nullifier_preimage.next_index = next_insertion_index;
            low_nullifier_preimage.next_value = new_nullifier;

            // Update state vals for the next iteration
            root = compute_root_from_leaf(low_nullifier_preimage.hash(), low_nullifier_index, low_nullifier_sibling_path);
            
            // Insert the nullifier leaf into our pending insertion subtree
            pending_insertion_subtree[i] = new_nullifier_leaf;
        }

        next_insertion_index += 1;
    }

    // Subtree insertion index = insertion at root >> depth of subtree;
    let subtree_insertion_index = ((next_available_index as u64) >> 2) as Field;

    // Check that the subtree we are inserting into is empty
    let empty_subtree_root: Field = empty_subtree(2);
    let empty = check_membership(root, empty_subtree_root, subtree_insertion_index, subtree_insertion_sibling_path);
    assert(empty == 1);

    // Perform batch insertion
    let pending_subtree_root: Field = get_pending_subtree_root(pending_insertion_subtree);
    root = compute_root_from_leaf(pending_subtree_root, subtree_insertion_index, subtree_insertion_sibling_path);
    root
}


fn get_pending_subtree_root(pending_nullifiers: [NullifierLeaf; 4]) -> Field {
    // Build a merkle tree of the nullifiers
    let depth = 2;
    let mut hashes: [Field; (4*2-2)] = [0; (4 * 2 - 2)];

    // Get the hashes of the base layer
    for i in 0..pending_nullifiers.len() {
        hashes[i] = pending_nullifiers[i].hash();
    }

    let mut offset = 0;
    let mut layer_size = 2;
    for i in 0..depth {
        for _j in 0..layer_size {
            hashes[i] = pedersen([hashes[offset], hashes[offset + 1]])[0];
            offset += 2;
        }
        layer_size = layer_size / 2;
    }
    hashes[4*2-1]
}


// Make the empty subtree, try do this unconstrained if possible / @ compilation
unconstrained fn empty_subtree(
    depth: comptime Field
) -> Field {
    let mut current: Field = 0;
    for _i in 0..depth {
        current = pedersen([current, current])[0];
    }
    current
}