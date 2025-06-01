import setuptools
from pathlib import Path

setuptools.setup(
    name = 'thoughtforms',
    version = '0.0.0',
    author = 'Kodi B. Arfer',
    description = 'Simple JavaScript-free Web surveys and experiments via WSGI',
    long_description = Path('README.rst').read_text(),
    long_description_content_type = 'text/x-rst',
    project_urls = {
        'Source Code': 'https://github.com/Kodiologist/thoughtforms'},
    install_requires = [
        'hy >= 1',
        'hyrule >= 1'],
    packages = setuptools.find_packages(),
    package_data = dict(thoughtforms = ['schema.sql'] + [
        str(p.relative_to('thoughtforms'))
        for p in Path('thoughtforms').rglob('*.hy')]),
    classifiers = [
        'License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)',
        'Operating System :: OS Independent',
        'Topic :: Software Development :: Libraries :: Application Frameworks',
        'Topic :: Internet :: WWW/HTTP :: WSGI :: Application'])

