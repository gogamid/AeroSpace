import Foundation

extension Array {
    func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }

    func singleOrNil(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element? {
        var found: Self.Element? = nil
        for elem in self {
            if try predicate(elem) {
                if found == nil {
                    found = elem
                } else {
                    return nil
                }
            }
        }
        return found
    }

    func firstOrThrow(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element {
        try first(where: predicate) ?? errorT("Can't find the element")
    }
}

extension Array where Self.Element : Equatable {
    @discardableResult
    public mutating func remove(element: Self.Element) -> Bool {
        if let index = firstIndex(of: element) {
            remove(at: index)
            return true
        } else {
            return false
        }
    }
}

func -<T>(lhs: [T], rhs: [T]) -> [T] where T: Hashable {
    let r = rhs.toSet()
    return lhs.filter { !r.contains($0) }
}