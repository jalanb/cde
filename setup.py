"""Set up the cde project"""

from setuptools import setup


setup(
    name='cde',
    version='0.7.31',
    url='https://github.com/jalanb/cde',
    license='MIT License',
    author="jalanb",
    author_email='github@al-got-rhythm.net',
    description='cde extends cd',
    platforms='Unix',
    classifiers=[
        'Programming Language :: Python :: 3.7',
        'Development Status :: 2 - Pre-Alpha',
        'Natural Language :: English',
        'Environment :: Console',
        'Intended Audience :: Developers',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: Unix',
        'Topic :: System :: Shells',
    ],
    install_requires=[
        'boltons',
        'pysyte',
    ],
    tests_require=[
        'pytest',
        'pytest-cov',
        'requests_mock',
    ],
    extras_require={
        'docs': ['Sphinx'],
        'testing': ['pytest'],
    },
    scripts=[
        'bin/cde',
    ],
)
