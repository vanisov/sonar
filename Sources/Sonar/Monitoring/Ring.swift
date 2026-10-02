/// Fixed-capacity history that overwrites its oldest entry: no per-sample shifting or reallocation.
struct Ring<Element>: RandomAccessCollection {
    let capacity: Int
    private var storage: [Element] = []
    private var head = 0  // oldest element once full

    init(capacity: Int = Monitor.historyLength) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var startIndex: Int { 0 }
    var endIndex: Int { storage.count }
    subscript(i: Int) -> Element { storage[(head + i) % storage.count] }

    mutating func append(_ value: Element) {
        if storage.count < capacity {
            storage.append(value)
        } else {
            storage[head] = value
            head = (head + 1) % capacity
        }
    }
}
