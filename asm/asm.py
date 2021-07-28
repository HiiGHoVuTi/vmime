
import click
import generator

@click.command()
@click.argument("path")
@click.option("--output", "-o")
@click.option("--verbose", "-v")
def main(path, output, verbose):
    # click.echo("{}, {}".format(greeting, name))
    output_path = output or path.split(".asm")[0] + ".o"
    with open(path) as source:
        output = generator.full_transpile(source.read())
        with open(output_path, "wb") as dist:
            if verbose != None:
                print(output)
            dist.write(bytes(output))
    click.echo("Compilation successful !")

if __name__ == "__main__":
    main()

