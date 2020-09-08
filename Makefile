

.PHONY: all clean

all: taekim_a4.pdf taekim_ebook.pdf taekim.epub

latex_pages:
	mkdir -p latex_pages
	mkdir -p raw_html/articles
	perl t2r.pl

taekim_ebook.pdf: latex_pages taekim_ebook.tex taekim_ebook.sty
	xelatex taekim_ebook
	xelatex taekim_ebook
	pdf90 --suffix 'turned' --batch taekim_ebook.pdf
	mv taekim_ebook-turned.pdf taekim_ebook.pdf

taekim_a4.pdf: latex_pages taekim_a4.tex taekim.sty
	xelatex taekim_a4
	xelatex taekim_a4

epub_pages:
	mkdir -p epub_pages
	mkdir -p raw_html/articles
	perl t2r.pl

taekim.epub: epub_pages taekim_epub.head taekim_epub.tail epub_pages
	echo not ready yet

texclean:
	$(RM) *.aux *.log *.out *.toc

clean:
	$(RM) taekim_a4.pdf taekim_ebook.pdf taekim.epub
	$(RM) -r latex_pages epub_pages
