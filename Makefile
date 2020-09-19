

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

taekim.epub:
	rm -r epub_pages
	cp -r epub epub_pages
	perl t3r.pl
	head epub_pages/content.opf -n19 > blah
	cat manifest.txt >> blah
	head epub_pages/content.opf -n24 | tail -n4 >> blah
	cat spine.txt >> blah
	tail epub_pages/content.opf -n2 >> blah
	mv blah epub_pages/content.opf
	head epub_pages/toc.ncx -n27 > blah2
	cat navmap.txt >> blah2
	tail epub_pages/toc.ncx -n2 >> blah2
	mv blah2 epub_pages/toc.ncx
	rm navmap.txt spine.txt manifest.txt
	cd epub_pages && zip ../taekim.epub *
	cd epub_pages && zip ../taekim.epub */*

verifyepub:
	xmllint epub_pages/OEBPS/*.xhtml --valid --noout
	xmllint epub_pages/titlepage*.xhtml --valid --noout
	xmllint epub_pages/toc.ncx --valid --noout
	xmllint epub_pages/content.opf --valid --noout
	xmllint epub_pages/META-INF/container.xml --valid --noout

texclean:
	$(RM) *.aux *.log *.out *.toc

clean:
	$(RM) taekim_a4.pdf taekim_ebook.pdf taekim.epub
	$(RM) -r latex_pages epub_pages
