"""Set up the kd project"""

import os
from setuptools import setup


import kd


p = os.path.join(os.path.dirname(__file__), 'requirements.txt')
with open(p) as stream:
    required = stream.read().splitlines()


setup(
    name='kd',
    version=kd.__version__,
    url='https://github.com/jalanb/kd',
    license='MIT License',
    author='J Alan Brogan',
    author_email='kd@al-got-rhythm.net',
    description=kd.__doc__.splitlines()[0],
    platforms='any',
    classifiers=[
        'Programming Language :: Python :: 2.7',
        'Development Status :: 2 - Pre-Alpha',
        'Natural Language :: English',
        'Environment :: Console',
        'Intended Audience :: Developers',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: Unix',
        'Topic :: System :: Shells',
    ],
    test_suite='nose.collector',
    install_requires=required,
    tests_require=['nose'],
    extras_require={
        'docs': ['Sphinx'],
        'testing': ['nose'],
    }
)
