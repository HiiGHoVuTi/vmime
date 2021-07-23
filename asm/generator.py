
def eval_loc(tree):
    val = tree.children[0].value
    if tree.value == "DeviceAddress":
        val2 = tree.children[1].value
        val, val2 = int(val, 16), int(val2, 16)
        return f"{val:04x}{val2:012x}", "Address"
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

def write_line(tree):
    if tree.value == "Call":
        instr, *_ = tree.children
        if child_value(instr).lower() == "mov":
            instr, to, fr = tree.children
            (to, to_type), (fr, fr_type) = eval_loc(to), eval_loc(fr)
            if fr_type == "Accumulator":
                if to_type == "Register":
                    return f"0x150{to}"
                return f"0x140{translate_loc(fr_type)} 0x{fr}"

            if to_type == fr_type == "Register":
                return "0x11" + fr + to

            if to_type == "Register":
                return f"0x12{translate_loc(fr_type)}{to} 0x{fr}"

            if fr_type == "Register":
                return f"0x13{to}{translate_loc(to_type)} 0x{to}"

            return f"0x10{translate_loc(fr_type)}{translate_loc(to_type)} 0x{fr} 0x{to}"

        if child_value(instr).lower() == "gth":
            instr, to, fr = tree.children
            (to, to_type), (fr, fr_type) = eval_loc(to), eval_loc(fr)
            assert to_type == fr_type == "Register"
            return f"0x16{fr}{to}"

        if child_value(instr).lower() == "psh":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr)
            if fr_type == "Register":
                return f"0x181{fr}"
            else:
                return f"0x180{translate_loc(fr_type)} 0x{fr}"

        if child_value(instr).lower() == "popa":
            return "0x1920"
    return "Invalid"


if __name__ == "__main__":
    from parser import grammar, print_tree
    commands = grammar().parseString(
"""
MOV r1 !abc
MOV r2 r1
MOV r1 acc
GTH r1 r1
PSH !12
PSH r1
POPA
"""
    )
    print_tree(("Program: ", commands))
    print("\n".join([write_line(cmd) for cmd in commands]))

