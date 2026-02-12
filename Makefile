.PHONY: test coverage lint lint-fix server console

test:
	bundle exec rspec

coverage:
	bundle exec rspec && open coverage/index.html

lint:
	bundle exec rubocop

lint-fix:
	bundle exec rubocop -A

server:
	bin/rails server

console:
	bin/rails console