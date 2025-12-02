class RingBuffer<T> {
  final int capacity;
  final List<T?> _buffer;
  int _writeOffset = 0;
  int _count = 0;

  RingBuffer(this.capacity) : _buffer = List<T?>.filled(capacity, null);

  void add(T value) {
    _buffer[_writeOffset] = value;
    _writeOffset = (_writeOffset + 1) % capacity;

    if (_count < capacity) {
      _count += 1;
    }
  }

  List<T> getValues() {
    // Return items in correct order (oldest first)
    final list = <T>[];
    for (int i = 0; i < _count; i += 1) {
      final index = (_writeOffset - _count + i) % capacity;
      list.add(_buffer[index < 0 ? index + capacity : index] as T);
    }
    return list;
  }

  int get length => _count;
  bool get isFull => _count == capacity;
}
