"""Types to make coding cde easier"""
import os
from typing import List


from pysyte.types import paths
from pysyte.types.lists import Unique
from pysyte.types.lists import UniquelyTrues


class PossiblePaths(UniquelyTrues):
    """A unique list of possible paths"""

    def convert(self, item: str) -> paths.StringPath:
        return paths.path(item)

    def predicate(self, item: str) -> bool:
        """Exclude items which don't exist"""
        return bool(item) and os.path.exists(item)

    def paths(self) -> List[paths.StringPath]:
        return [_ for _ in self if self.predicate(_)]


class UniquePaths(PossiblePaths):
    def __contains__(self, item: Unique) -> bool:
        for path in self:
            if path.same_path(item):
                return True
        return False


class Roots(UniquePaths):
    def predicate(self, item: str) -> bool:
        path_ = paths.path(item)
        if path_ in self:
            return False
        if path_.parent in self:
            return False
        for i, root in enumerate(self):
            if root.parent.same_path(path_):
                break
        else:
            self[i] = path_
        return False
