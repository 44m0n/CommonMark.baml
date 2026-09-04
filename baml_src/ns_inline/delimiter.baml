class Delimiter {
    kind: string,
    count: int,
    orig_count: int,
    active: bool,
    can_open: bool,
    can_close: bool,
    inline_index: int,
}

class DelimiterStack {
    items: Delimiter[],
}

class Bracket {
    image: bool,
    active: bool,
    bracket_after: bool,
    inline_index: int,
    opener_pos: int,
    delim_bottom: int,
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
    stack_push(
        stack,
        Delimiter {
            kind: "*",
            count: 1,
            orig_count: 1,
            active: true,
            can_open: true,
            can_close: false,
            inline_index: 0,
        },
    );
    stack_push(
        stack,
        Delimiter {
            kind: "_",
            count: 2,
            orig_count: 2,
            active: true,
            can_open: false,
            can_close: true,
            inline_index: 1,
        },
    );
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
    let d = Delimiter {
        kind: "[",
        count: 1,
        orig_count: 1,
        active: true,
        can_open: true,
        can_close: false,
        inline_index: 0,
    };
    assert.is_true(d.can_open);
    assert.equal(d.can_close, false);
    assert.is_true(d.active)
}
