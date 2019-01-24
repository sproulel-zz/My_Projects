import numpy as np
import heapq
import random

x = np.array([random.randint(-10,10)*x for x in range(2000)])

print(heapq.nlargest(4,x))
print(heapq.nsmallest(4,x))

def nlargest(n,iterable):
    return sorted(iterable, reverse=True)[:n]

def nsmallest(n, iterable):
    return sorted(iterable)[:n]
print(nlargest(4,x))
print(nsmallest(4,x))
