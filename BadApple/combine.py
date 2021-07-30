
with open("display.o", "ab") as script:
    with open("output.raw", "rb") as data:
        script.write(data.read())
