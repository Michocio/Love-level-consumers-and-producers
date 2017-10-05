# Love-level-consumers-and-producers
Consumers and producers problem's implementation in ASM.

**dijkstra_semaphore** - implementation of semaphore based on Dijkstra definition. It means that semaphore is rised when value
is higher than zero. Operations are implemented in such a way:

*P(semaphore)* - wait until value of semaphore is higher than zero and than substract from semaphore value.

*V(semaphore)* - add to semaphore value.

**dijkstra_semaphore** file shares functions *proberen* and *verhogen* which are later used by program **producer_consumer** which is
simulation of classic problem of synchronization.
