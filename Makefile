
all:
	nikola build

deploy:
	nikola deploy

clean:
	rm -rf output cache __pycache__

