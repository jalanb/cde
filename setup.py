"""Set up the kd project"""


from setuptools import setup


import kd


setup(
    name='kd',
    version=kd.__version__,
    url='https://github.com/jalanb/kd',
    license='MIT License',
    author='J Alan Brogan',
    author_email='kd@al-got-rhythm.net',
    description='kd is a smarter cd',
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
    tests_require=['nose'],
    extras_require={
        'docs': ['Sphinx'],
        'testing': ['nose'],
    }
)
