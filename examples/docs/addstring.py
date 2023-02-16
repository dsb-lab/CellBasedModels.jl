import io

l = [
    "../../docs/src/Usage_Community.md",
    "../../docs/src/Usage_Fitting.md",
]

for file in l:
    f = open(file, "r", encoding="utf-8")
    d = f.read()
    d = d.split("<table>")
    ffinal = d[0]
    for i in d[1:]:
        ffinal += "\n```@raw html\n <table>"
        ffinal += i

    d = ffinal.split("<p>DataFrameRow")
    ffinal = d[0]
    for i in d[1:]:
        ffinal += "\n```@raw html\n <p>DataFrameRow"
        ffinal += i

    d = ffinal.split("</table>")
    ffinal = d[0]
    for i in d[1:]:
        ffinal += "</table> \n```\n"
        ffinal += i

    with open(file, 'w') as file:
        file.write(ffinal)