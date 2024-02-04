chapters = book.md
template = Templates/blauwal.tex
output = vmp-documentation.pdf

all: $(chapters)
	pandoc --pdf-engine=xelatex --from markdown --template \
	$(template) --top-level-division=chapter --listings -o \
	$(output) $(chapters)

clean:
	rm $(output)