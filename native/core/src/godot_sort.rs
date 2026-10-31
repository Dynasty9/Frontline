//! Preserve Array.sort_custom tie order used by cover's bounded candidate search.
//! Adapted from Godot's core/templates/sort_array.h; see ../GODOT-LICENSE.txt.

pub(crate) fn score_order(scores: &[f64]) -> Vec<usize> {
    let mut order: Vec<_> = (0..scores.len()).collect();
    if order.is_empty() {
        return order;
    }
    let depth = (usize::BITS - 1 - order.len().leading_zeros()) as usize * 2;
    let length = order.len();
    introsort(&mut order, scores, 0, length, depth);
    for i in 1..length {
        let value = order[i];
        let mut at = i;
        while at > 0 && scores[value] < scores[order[at - 1]] {
            order[at] = order[at - 1];
            at -= 1;
        }
        order[at] = value;
    }
    order
}

fn median(order: &[usize], scores: &[f64], a: usize, b: usize, c: usize) -> usize {
    let less = |a: usize, b: usize| scores[order[a]] < scores[order[b]];
    if less(a, b) {
        if less(b, c) {
            b
        } else if less(a, c) {
            c
        } else {
            a
        }
    } else if less(a, c) {
        a
    } else if less(b, c) {
        c
    } else {
        b
    }
}

fn introsort(order: &mut [usize], scores: &[f64], first: usize, mut last: usize, mut depth: usize) {
    while last - first > 16 {
        if depth == 0 {
            heap_sort(&mut order[first..last], scores);
            return;
        }
        depth -= 1;
        let pivot = median(order, scores, first, first + (last - first) / 2, last - 1);
        let value = scores[order[pivot]];
        let mut left = first;
        let mut right = last;
        loop {
            while left != pivot && scores[order[left]] < value {
                left += 1;
            }
            right -= 1;
            while right != pivot && value < scores[order[right]] {
                right -= 1;
            }
            if left >= right {
                break;
            }
            order.swap(left, right);
            left += 1;
        }
        introsort(order, scores, left, last, depth);
        last = left;
    }
}

fn push_heap(order: &mut [usize], scores: &[f64], mut hole: usize, top: usize, value: usize) {
    while hole > top {
        let parent = (hole - 1) / 2;
        if scores[order[parent]] >= scores[value] {
            break;
        }
        order[hole] = order[parent];
        hole = parent;
    }
    order[hole] = value;
}

fn adjust_heap(order: &mut [usize], scores: &[f64], mut hole: usize, value: usize) {
    let top = hole;
    let mut second_child = 2 * hole + 2;
    while second_child < order.len() {
        if scores[order[second_child]] < scores[order[second_child - 1]] {
            second_child -= 1;
        }
        order[hole] = order[second_child];
        hole = second_child;
        second_child = 2 * (second_child + 1);
    }
    if second_child == order.len() {
        order[hole] = order[second_child - 1];
        hole = second_child - 1;
    }
    push_heap(order, scores, hole, top, value);
}

fn heap_sort(order: &mut [usize], scores: &[f64]) {
    if order.len() < 2 {
        return;
    }
    for parent in (0..=(order.len() - 2) / 2).rev() {
        adjust_heap(order, scores, parent, order[parent]);
    }
    for last in (1..order.len()).rev() {
        let value = order[last];
        order[last] = order[0];
        adjust_heap(&mut order[..last], scores, 0, value);
    }
}

#[cfg(test)]
mod tests {
    use super::score_order;
    #[test]
    fn candidate_sort_handles_ties_and_adversarial_runs() {
        for n in [0, 1, 2, 16, 17, 20, 100, 1000] {
            for mode in 0..5 {
                let scores: Vec<_> = (0..n)
                    .map(|i| match mode {
                        0 => i as f64,
                        1 => (n - i) as f64,
                        2 => 0.0,
                        3 => (i % 4) as f64,
                        _ => (i.min(n - i) % 30) as f64,
                    })
                    .collect();
                let result = score_order(&scores);
                assert!(result
                    .windows(2)
                    .all(|pair| scores[pair[0]] <= scores[pair[1]]));
                let mut membership = result;
                membership.sort_unstable();
                assert_eq!(membership, (0..n).collect::<Vec<_>>());
            }
        }
    }
}
