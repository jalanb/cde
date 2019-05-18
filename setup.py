"""Set up the cde project"""

import os
from setuptools import setup


import cde


p = os.path.join(os.path.dirname(__file__), 'requirements.txt')
with open(p) as stream:
    required = stream.read().splitlines()


setup(
    name='cde',
    version=cde.__version__,
    url='https://github.com/jalanb/cde',
    license='MIT License',
    author="jalanb",
    author_email='github@al-got-rhythm.net',
    description=cde.__doc__.splitlines()[0],
    platforms='Unix',
    classifiers=[
        'Programming Language :: Python :: 3.6',
        'Development Status :: 2 - Pre-Alpha',
        'Natural Language :: English',
        'Environment :: Console',
        'Intended Audience :: Developers',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: Unix',
        'Topic :: System :: Shells',
    ],
    install_requires=required,
    tests_require=['pytest'],
    extras_require={
        'docs': ['Sphinx'],
        'testing': ['pytest'],
    }
)
