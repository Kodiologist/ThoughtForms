ThoughtForms
!!!!!!!!!!!!

ThoughtForms is a low-dependency Python web framework for administering surveys and psychology experiments, particularly on `Prolific <https://prolific.com>`__. It produces simple form-based dynamic HTML without JavaScript, and it saves data with SQLite. An interface is provided for creating a WSGI application via `Werkzeug <https://werkzeug.palletsprojects.com>`__, but you can also call slightly lower-level functions to manually link up with a web server, so Werkzeug isn't a hard dependency. Another optional dependency is `Requests <https://requests.readthedocs.io>`__, for ``thoughtforms.prolific``.

Currently, ThoughtForms is immature and mostly undocumented.

This library is similar to and uses ideas from my earlier libraries `Tversky <https://github.com/Kodiologist/Tversky>`__ (for Perl CGI programs) and `SchizoidPy <https://github.com/Kodiologist/SchizoidPy>`__ (for Python native applications via PsychoPy).

Licenses
============================================================

ThoughtForms as a whole is licensed under the GPL ≥3. It contains portions of the package more-itertools, which is subject to the Expat license below.

License for ThoughtForms
------------------------------------------------------------

This program is copyright 2024 Kodi B. Arfer.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU General Public License`_ for more details.

.. _`GNU General Public License`: http://www.gnu.org/licenses/

License for more-itertools
------------------------------------------------------------

Copyright (c) 2012 Erik Rose

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
