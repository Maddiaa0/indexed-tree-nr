use dep::std::hash::pedersen;

struct NullifierLeaf {
    value: Field,
    next_index: Field,
    next_value: Field
}

impl NullifierLeaf {
    fn new(value: Field, next_index: Field, next_value: Field) -> Self{
        NullifierLeaf {
            value,
            next_index,
            next_value
        }
    }

    fn empty() -> Self {
        NullifierLeaf {
            value: 0,
            next_index: 0,
            next_value: 0
        }
    }

    fn is_empty(self) -> bool {
        (self.value == 0) & (self.next_index == 0) & (self.next_value == 0)
    }

    fn hash(self) -> Field {
        if self.is_empty() {
            0
        } else {
            pedersen([self.value, self.next_index, self.next_value])[0]
        }
    }
}

