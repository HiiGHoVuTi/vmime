
import copy
import re

def regex_replace_ld(pattern, string, fn, *args):
    match = re.search(pattern, string)
    if match == None:
        return string
    start, end = match.span()
    sub = string[start:end]
    newsub = fn(sub, *args)
    return string[:start] + newsub + string[end:]


def eval_loc(tree, props):
    val = tree.children[0].value
    if tree.value == "DeviceAddress":
        val2 = tree.children[1].value
        val, val2 = int(val, 16), int(val2, 16)
        return f"{val:04x}{val2:012x}", "Address"
    if tree.value == "Label":
        addr = props["labels"].get(val)
        if addr == None:
            addr = "!E" + val + "!"
            return addr, "Literal"
        return f'{addr:x}', "Literal"
    return val, tree[0]

def resolve_unknown_label(lab, props):
    label = lab[2:-1]
    value = props["labels"].get(label)
    if value == None:
        # if "end_Main Program" not in props["labels"]:
        #    raise Exception("Label " + label + " is undefined !")
        return lab
    return f"{value:x}"

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
        # careful
        props["labels"][child_value(name)] = props["total bits"]

        old_labels = props["labels"]
        newprops = props
        newprops["labels"] = copy.copy(props["labels"])
        retval = "\n".join(write_line(instr, props) for instr in instrs)

        # hmm
        # props["labels"] = old_labels
        props["labels"]["end_" + child_value(name)] = props["total bits"]

        return regex_replace_ld("!E.*!", retval, resolve_unknown_label, props)

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
            return register_binops[instr_name] + fr + to + ":16"

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
                return f"0x1a1{fr}:16"
            else:
                props["total bits"] += 16 + 64
                return f"0x1a0{translate_loc(fr_type)}:16 0x{fr}:64"

        if instr_name == "pop":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            assert fr_type == "Accumulator"
            props["total bits"] += 16
            return "0x1f20:16"

        if instr_name == "jnq":
            instr, to, fr = tree.children
            (fr, fr_type), (to, to_type) = eval_loc(to, props), eval_loc(fr, props)
            if fr_type == "Accumulator":
                props["total bits"] += 16 + 64
                return f"0x331{translate_loc(to_type)}:16 0x{to}:64"

            props["total bits"] += 16 + 64 + 64
            return f"0x35{translate_loc(fr_type)}{translate_loc(to_type)}:16 0x{fr}:64 0x{to}:64"
        if instr_name == "jmp":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            props["total bits"] += 16 + 64
            return f"0x390{translate_loc(fr_type)}:16 0x{fr}:64"

        if instr_name == "cal":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            assert fr_type == "Register"
            props["total bits"] += 16
            return f"0x3A0{fr}:16"

        if instr_name == "ret":
            instr, fr = tree.children
            (fr, fr_type) = eval_loc(fr, props)
            if fr == "acc":
                fr = "0"
            props["total bits"] += 16 + 64
            return f"0x3F0{translate_loc(fr_type)}:16 0x{fr}:64"


        if instr_name == "hlt":
            props["total bits"] += 16
            return "0xffff:16"

    return "Invalid: " + tree.value


from pyqol.All import IC, L
def create_bytearray(instructions, total_size):
    arr = bytearray(total_size // 8)
    idx = 0

    for instr in instructions.split():
        # get the info from the instruction, removing the "0x"
        val, size = instr.split(':')
        val = L(*val)[2:]
        # reverse the sequence because Big Endian
        val.reverse()
        # idx points to the end of the instruction, and nidx will walk backward
        idx += int(size) // 8
        nidx = idx
        # two hex characters create a single byte
        for ck in IC(val, chunk_size=2):
            nidx -= 1
            ck.reverse()
            arr[nidx] = int("".join(ck), 16)
        # deal with an isolated character
        if len(val) & 1:
            nidx -= 1
            arr[nidx] = int(val[-1], 16)

    return arr

def full_transpile(source):
    from parser import grammar, print_tree, graph_tree, Node

    commands = grammar().parseString(source)
    props = {"total bits": 0, "labels": {}}
    # graph_tree(("Entry", commands))
    # print_tree(("Program: ", commands))
    instr = write_line(Node(
        "Sequence",
        [ Node("Instr", [("Main Program", )])
        , *commands]
    ), props)
    # print(regex_replace_ld("!E.*!", retval, resolve_unknown_label, props))

    array = create_bytearray(instr, props["total bits"])
    return array

if __name__ == "__main__":
    from parser import grammar, print_tree, graph_tree, Node
    commands = grammar().parseString(
"""
main {
   MOV r1 !5
   MOV r2 :print
   loop {
      DEC r1
      PSH r1
      CAL r2
      AND r1 r1
      JNQ acc :loop
      JMP :end_loop
   }
   HLT
}
print {
    POP acc
    RET acc
}
"""
    )
    props = {"total bits": 0, "labels": {}}
    graph_tree(("Entry", commands))
    print_tree(("Program: ", commands))
    instr = write_line(Node(
        "Sequence",
        [ Node("Instr", [("Main Program", )])
        , *commands]
    ), props)
    # print(regex_replace_ld("!E.*!", retval, resolve_unknown_label, props))
    print(instr)

    array = create_bytearray(instr, props["total bits"])
    print(array)


