class Delimiter {
    kind: string,
    count: int,
    active: bool,
    can_open: bool,
    can_close: bool,
}

class DelimiterStack {
    items: Delimiter[],
}

function delimiter_stack() -> DelimiterStack {
    DelimiterStack { items: [] }
}

function stack_push(stack: DelimiterStack, d: Delimiter) -> void {
    stack.items.push(d)
}

function stack_pop(stack: DelimiterStack) -> Delimiter? {
    stack.items.pop()
}

function stack_top(stack: DelimiterStack) -> Delimiter? {
    stack.items.at(stack.items.length() - 1)
}

test "push and pop maintain LIFO order" {
    let stack = delimiter_stack();
    stack_push(stack, Delimiter { kind: "*", count: 1, active: true, can_open: true, can_close: false });
    stack_push(stack, Delimiter { kind: "_", count: 2, active: true, can_open: false, can_close: true });
    let top = stack_top(stack);
    assert.equal(top?.kind, "_");
    assert.equal(top?.count, 2);
    let popped = stack_pop(stack);
    assert.equal(popped?.kind, "_");
    let second = stack_pop(stack);
    assert.equal(second?.kind, "*");
    assert.equal(stack_pop(stack), null)
}

test "delimiter records open and close flags" {
    let d = Delimiter { kind: "[", count: 1, active: true, can_open: true, can_close: false };
    assert.is_true(d.can_open);
    assert.equal(d.can_close, false);
    assert.is_true(d.active)
}
