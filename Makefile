pre-push:
	make compile && make lint && make test

compile:
	rm -rf _build/dev/lib/quantum && mix compile --warnings-as-errors

lint:
	mix format && make dialyzer

dialyzer:
	mix dialyzer --format dialyxir

test:
	mix test
