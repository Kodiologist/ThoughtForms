#!/usr/bin/env python3

from pathlib import Path
from pprint import pprint

import werkzeug
import thoughtforms
from thoughtforms.task import FREE_RESPONSE
from thoughtforms.html import E

db_path = Path('/tmp/thoughtforms.sqlite')

def task_callback(task, page):

    task.consent_form()

    page('continue', 'intro', [
        E.p('This is the first page of the task.'),
        E.p('Its only interface is a button labeled "Continue".')])

    for letter in 'ABC':
        page('choice', f'rate_{letter}',
            E.p(f'How much do you like the letter {letter}?'),
            {
                 5: 'I love it!',
                 4: "I'm cool with it.",
                 3: 'I have no strong feelings one way or the other.',
                 2: "I'm not crazy about it.",
                 1: "I can't stand that stupid letter."})
    page('continue', 'after',
        E.p('You gave this rating for the letter B: ', str(task.dval('rate_B'))))

    page('enter-number', 'age',
        E.p('How old are you?'),
        type = int, sign = 1)

    page('checkbox', 'continent',
        E.p('Which continents have you visited? (Choose all that apply.)'),
        dict(
            As = 'Asia',
            Af = 'Africa',
            NA = 'North America',
            SA = 'South America',
            An = 'Antarctica',
            Eu = 'Europe',
            Au = 'Australia',
            Extraterrestral = FREE_RESPONSE),
        min = 1)

    page('textbox', 'comments',
        E.p(E.em('(Optional) '), 'Comments on this study'),
        optional = True)

    task.complete()

def application():
    return thoughtforms.wsgi_application(
        task_callback,
        db_path = db_path,
        task_version = '0.0.1',
        page_title = 'Task',
        language = 'en-US',
        cookie_path = '/',
        consent_elements = E.p('This is the consent form.'))

if __name__ == '__main__':

    if not db_path.exists():
        thoughtforms.db.initialize(db_path)

    print('Once the server starts, try visiting:')
    print('http://127.0.0.1:5000/task?PROLIFIC_PID=cafebabe&STUDY_ID=deadbeef&SESSION_ID=d00d')
    werkzeug.serving.run_simple('127.0.0.1', 5000, application())

    print('\n\n\n-------------------- Results --------------------\n')
    pprint(thoughtforms.db.read(db_path))
