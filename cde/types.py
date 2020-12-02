"""Types to make coding cde easier"""
import os


from pysyte.types.lists import UniquelyTrues


class PossiblePaths(UniquelyTrues):
    """A unique list of possible paths"""

    def predicate(self, item):
        return bool(item) and os.path.exists(item)

    def paths(self):
        return [paths.path(_) for _ in self]
