
.PHONY: deps

defaul: build

deps:
	@go get github.com/tdewolff/minify/cmd/minify

dev: clean
	@if [ $$USER = 'vagrant' ]; then \
		HUGO_DEV=true hugo server -w --bind=0.0.0.0 --baseURL=http://$(shell ifconfig eth1 | grep -E 'addr:[0-9.]*' -o -m 1  | cut -d ':' -f 2) -d dev;\
	else \
		HUGO_DEV=true hugo server -wD -d dev ;\
	fi

build: clean
	hugo
	@rm public/styles/*.css
	@minify -f -o public/styles/main.css themes/fraixedes/static/styles/main.css

clean:
	rm -rf public dev

minify-css: