from math import factorial, perm


def nth_permutation(iterable, r, index):
    # Copied from https://github.com/more-itertools/more-itertools/blob/v10.5.0/more_itertools/more.py#L4072
    # I figured it was better to copy than depend because we only need
    # one function.

    """Equivalent to ``list(permutations(iterable, r))[index]```

    The subsequences of *iterable* that are of length *r* where order is
    important can be ordered lexicographically. :func:`nth_permutation`
    computes the subsequence at sort position *index* directly, without
    computing the previous subsequences.

        >>> nth_permutation('ghijk', 2, 5)
        ('h', 'i')

    ``ValueError`` will be raised If *r* is negative or greater than the length
    of *iterable*.
    ``IndexError`` will be raised if the given *index* is invalid.
    """
    pool = list(iterable)
    n = len(pool)

    if r is None or r == n:
        r, c = n, factorial(n)
    elif not 0 <= r < n:
        raise ValueError
    else:
        c = perm(n, r)
    assert c > 0  # factortial(n)>0, and r<n so perm(n,r) is never zero

    if index < 0:
        index += c

    if not 0 <= index < c:
        raise IndexError

    result = [0] * r
    q = index * factorial(n) // c if r < n else index
    for d in range(1, n + 1):
        q, i = divmod(q, d)
        if 0 <= n - d < r:
            result[n - d] = i
        if q == 0:
            break

    return tuple(map(pool.pop, result))
