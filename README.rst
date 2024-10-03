ThoughtForms
!!!!!!!!!!!!

ThoughtForms is a low-dependency Python web framework for administering surveys and psychology experiments, particularly on `Prolific <https://prolific.com>`__. It produces simple form-based dynamic HTML without JavaScript, and it saves data with SQLite. An interface is provided for creating a WSGI application via `Werkzeug <https://werkzeug.palletsprojects.com>`__, but you can also call slightly lower-level functions to manually link up with a web server, so Werkzeug isn't a hard dependency.

Currently, ThoughtForms is immature and mostly undocumented.

This library is similar to and uses ideas from my earlier libraries `Tversky <https://github.com/Kodiologist/Tversky>`__ (for Perl CGI programs) and `SchizoidPy <https://github.com/Kodiologist/SchizoidPy>`__ (for Python native applications via PsychoPy).

License
============================================================

This program is copyright 2024 Kodi B. Arfer.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU General Public License`_ for more details.

.. _`GNU General Public License`: http://www.gnu.org/licenses/

