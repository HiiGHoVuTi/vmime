
from pyparsing import *

import pydot

from collections import namedtuple

Node = namedtuple("Node", ["value", "children"])

def print_tree(node, tab="", print_first_branch=True):
    print (tab + (u"┗━ " if print_first_branch else "") + str(node[0]))
    for child in node[1]:
        print_tree(child, tab + "    ")

def graph_tree(node):
    graph = pydot.Dot("my_graph", graph_type="graph", bgcolor="black")
    convert_tree(graph, node)
    graph.write_svg("graph.svg")
    graph.write_png("graph.png")

def convert_tree(graph, node, prop={'id': 0}):
    prop['id'] += 1
    id = prop['id']
    graph.add_node(pydot.Node(f"{id}", label=node[0], fontcolor="white"))
    for i, child in enumerate(node[1]):
        nid = convert_tree(graph, child, prop)
        graph.add_edge(pydot.Edge(f"{id}", f"{nid}", color="white"))
    return id


def printurn(x):
    print(x)
    return x

def grammar():
    # Setup
    minipack = lambda n: lambda x: Node(n, list(x))
    pack = lambda n: lambda x: Node(n, [Node(a, []) for a in x])
    ParserElement.enablePackrat()

    hexnums = nums + "abcdef"

    # Grammar
    instr = Word(alphas)
    instr.setParseAction(pack("Instr"))

    acc      = Literal("acc")
    acc.setParseAction(pack("Accumulator"))
    register = Literal("r").suppress() + Word(hexnums)
    register.setParseAction(pack("Register"))
    literal = Literal("!").suppress() + Word(hexnums)
    literal.setParseAction(pack("Literal"))
    address = Literal("@").suppress() + Word(hexnums)
    address.setParseAction(pack("Address"))
    deviceAddress = Literal("@").suppress() + Word(hexnums) + Literal(":").suppress() + Word(hexnums)
    deviceAddress.setParseAction(pack("DeviceAddress"))

    operand = acc | register | literal | deviceAddress | address

    instr_call = instr + ZeroOrMore(operand)
    instr_call.setParseAction(minipack("Call"))

    stmt = instr_call

    return ZeroOrMore(stmt)


if __name__ == "__main__":
    g = grammar()
    print_tree(Node("Code", g.parseString(
"""
MOV r1 @1:8
MOV !a @3
""")))
