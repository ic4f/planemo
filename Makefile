# Default tests run with make test and make quick-tests
NOSE_TESTS?=tests planemo
# Default environment for make tox
ENV?=py27
# Extra arguments supplied to tox command
ARGS?=
# Location of virtualenv used for development.
VENV?=.venv
# Source virtualenv to execute command (flake8, sphinx, twine, etc...)
IN_VENV=if [ -f $(VENV)/bin/activate ]; then . $(VENV)/bin/activate; fi;
# TODO: add this upstream as a remote if it doesn't already exist.
UPSTREAM?=galaxyproject
SOURCE_DIR?=planemo
BUILD_SCRIPTS_DIR=scripts
VERSION?=$(shell python $(BUILD_SCRIPTS_DIR)/print_version_for_release.py $(SOURCE_DIR))
DOC_URL?=https://planemo.readthedocs.org
PROJECT_URL?=https://github.com/galaxyproject/planemo
PROJECT_NAME?=planemo
TEST_DIR?=tests

.PHONY: clean-pyc clean-build docs clean

help:
	@grep -P '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean: clean-build clean-pyc clean-test ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/

setup-venv: ## setup a development virutalenv in current directory
	if [ ! -d $(VENV) ]; then virtualenv $(VENV); exit; fi;
	$(IN_VENV) pip install -r requirements.txt && pip install -r dev-requirements.txt

setup-git-hook-lint: ## setup precommit hook for linting project
	cp $(BUILD_SCRIPTS_DIR)/pre-commit-lint .git/hooks/pre-commit

setup-git-hook-lint-and-test: ## setup precommit hook for linting and testing project
	cp $(BUILD_SCRIPTS_DIR)/pre-commit-lint-and-test .git/hooks/pre-commit

flake8: ## check style using flake8 for current Python (faster than lint)
	$(IN_VENV) flake8 --max-complexity 11 $(SOURCE_DIR)  $(TEST_DIR)

lint: ## check style using tox and flake8 for Python 2 and Python 3
	$(IN_VENV) tox -e py27-lint && tox -e py34-lint

lint-readme: ## check README formatting for PyPI
	$(IN_VENV) python setup.py check -r -s

test: ## run tests with the default Python (faster than tox)
	$(IN_VENV) nosetests $(NOSE_TESTS)

quick-test: ## run quickest tests with the default Python
	$(IN_VENV) PLANEMO_SKIP_GALAXY_TESTS=1 nosetests $(NOSE_TESTS)

tox:
	$(IN_VENV) tox -e $(ENV) -- $(ARGS)

coverage: ## check code coverage quickly with the default Python
	coverage run --source $(SOURCE_DIR) setup.py $(TEST_DIR)
	coverage report -m
	coverage html
	open htmlcov/index.html || xdg-open htmlcov/index.html

ready-docs:
	rm -f docs/$(SOURCE_DIR).rst
	rm -f docs/planemo_ext.rst
	rm -f docs/modules.rst
	$(IN_VENV) sphinx-apidoc -f -o docs/ planemo_ext planemo_ext/galaxy/eggs
	$(IN_VENV) sphinx-apidoc -f -o docs/ $(SOURCE_DIR)

docs: ready-docs ## generate Sphinx HTML documentation, including API docs
	$(IN_VENV) $(MAKE) -C docs clean
	$(IN_VENV) $(MAKE) -C docs html

_open-docs:
	open docs/_build/html/index.html || xdg-open docs/_build/html/index.html

open-docs: docs _open-docs ## generate Sphinx HTML documentation and open in browser

open-rtd: docs ## open docs on readthedocs.org
	open $(DOC_URL) || xdg-open $(PROJECT_URL)

open-project: ## open project on github
	open $(PROJECT_URL) || xdg-open $(PROJECT_URL)

dist: clean ## package
	$(IN_VENV) python setup.py sdist bdist_egg bdist_wheel
	ls -l dist

release-test-artifacts: dist
	$(IN_VENV) twine upload -r test dist/*
	open https://testpypi.python.org/pypi/$(PROJECT_NAME) || xdg-open https://testpypi.python.org/pypi/$(PROJECT_NAME)

release-aritfacts: release-test-artifacts
	@while [ -z "$$CONTINUE" ]; do \
		read -r -p "Have you executed release-test and reviewed results? [y/N]: " CONTINUE; \
	done ; \
	[ $$CONTINUE = "y" ] || [ $$CONTINUE = "Y" ] || (echo "Exiting."; exit 1;)
	@echo "Releasing"
	$(IN_VENV) twine upload dist/*

commit-version:
	$(IN_VENV) python $(BUILD_SCRIPTS_DIR)/commit_version.py $(SOURCE_DIR) $(VERSION)

new-version:
	$(IN_VENV) python $(BUILD_SCRIPTS_DIR)/new_version.py $(SOURCE_DIR) $(VERSION)

release-local: commit-version release-aritfacts new-version

release-brew:
	bash $(BUILD_SCRIPTS_DIR)/update_planemo_recipe.bash $(VERSION)

push-release:
	git push $(UPSTREAM) master
	git push --tags $(UPSTREAM)

release: release-local push-release release-brew ## package, review, and upload a release

add-history:
	$(IN_VENV) python $(BUILD_SCRIPTS_DIR)/bootstrap_history.py $(ITEM)

update-extern: ## update external artifacts copied locally
	sh scripts/update_extern.sh
