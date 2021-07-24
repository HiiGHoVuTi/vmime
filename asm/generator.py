
def eval_loc(tree, props):
    val = tree.children[0].value
    if tree.value == "DeviceAddress":
        val2 = tree.children[1].value
        val, val2 = int(val, 16), int(val2, 16)
        return f"{val:04x}{val2:012x}", "Address"
    if tree.value == "Label":
        return f'{props["labels"][val]:x}', "Literal"
    return val, tree[0]

def translate_loc(loc):
    return {
        "Literal"    : 0x0,
        "Accumulator": 0x1,
        "Register"   : 0x2,
        "Address"    : 0x3,
        "Pointer"    : 0x4,
    }[loc]

def child_value(x):
    return x[1][0][0]


register_binops = {
    "and": "0x03",
    "or" : "0x04",
    "xor": "0x05",
    "rsh": "0x06",
    "lsh": "0x07",
}


def write_line(tree, props):

    if tree.value == "Sequence":
        name, *instrs = tree.children
        props["labels"][child_value(name)] = props["total bits"]
        return "\n".join(write_line(instr, props) for instr in instrs)

    if tree.value == "Call":
        instr, *_ = tree.children
        instr_name = child_value(instr).lower()

        if instr_name == "nop":
            props["total bits"] += 16
            return "0x0000:16"

        if instr_name == "inc":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            assert fr_type == "Register"
            props["total bits"] += 16
            return f"0x010{fr}:16"

        if instr_name == "dec":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            assert fr_type == "Register"
            props["total bits"] += 16
            return f"0x020{fr}:16"

        if instr_name in register_binops:
            instr, to, fr = tree.children
            (to, to_type), (fr, fr_type) = eval_loc(to, props), eval_loc(fr, props)
            assert to_type == fr_type == "Register"
            props["total bits"] += 16
            return register_binops[instr_name] + fr + to

        if instr_name == "mov":
            instr, to, fr = tree.children
            (to, to_type), (fr, fr_type) = eval_loc(to, props), eval_loc(fr, props)
            if fr_type == "Accumulator":
                if to_type == "Register":
                    props["total bits"] += 16
                    return f"0x150{to}:16"
                props["total bits"] += 16 + 64
                return f"0x140{translate_loc(fr_type)}:16 0x{fr}:64"

            if to_type == fr_type == "Register":
                props["total bits"] += 16 + 64
                return "0x11" + fr + to + ":16"

            if to_type == "Register":
                props["total bits"] += 16 + 64
                return f"0x12{translate_loc(fr_type)}{to}:16 0x{fr}:64"

            if fr_type == "Register":
                props["total bits"] += 16 + 64
                return f"0x13{to}{translate_loc(to_type)}:16 0x{to}:64"
            props["total bits"] += 16 + 64 + 64
            return f"0x10{translate_loc(fr_type)}{translate_loc(to_type)}:16 0x{fr}:64 0x{to}:64"

        if instr_name == "gth":
            instr, to, fr = tree.children
            (to, to_type), (fr, fr_type) = eval_loc(to, props), eval_loc(fr, props)
            assert to_type == fr_type == "Register"
            props["total bits"] += 16
            return f"0x16{fr}{to}:16"

        if instr_name == "psh":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            if fr_type == "Register":
                props["total bits"] += 16
                return f"0x181{fr}:16"
            else:
                props["total bits"] += 16 + 64
                return f"0x180{translate_loc(fr_type)}:16 0x{fr}:64"

        if instr_name == "pop":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            assert fr_type == "Accumulator"
            props["total bits"] += 16
            return "0x1920:16"

    return "Invalid: " + tree.value


if __name__ == "__main__":
    from parser import grammar, print_tree, graph_tree
    commands = grammar().parseString(
"""
clutter {
   MOV !0 !0
}
main {
    MOV r1 !1337
    PSH r1
}
otherpart {
    MOV r1 :main
}
"""
    )
    props = {"total bits": 0, "labels": {}}
    # graph_tree(("Entry", commands))
    print_tree(("Program: ", commands))
    print("\n".join([write_line(cmd, props) for cmd in commands]))

