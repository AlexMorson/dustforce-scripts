class HashMap {
    [hidden] uint size = 0;
    [hidden] uint buckets = 8;
    [hidden] array<array<Node>> table = array<array<Node>>(buckets);

    void debug() {
        puts("size:" + size + "\nbuckets:" + buckets);
        for (uint i=0; i<buckets; ++i) {
            puts(i + ":");
            for (uint j=0; j<table[i].size(); ++j) {
                puts("" + table[i][j].key);
            }
        }
    }

    void clear() {
        size = 0;
        buckets = 8;
        table = array<array<Node>>(buckets);
    }

    HashMapIterator iter() {
        return HashMapIterator(this);
    }
    
    TileFilth@ get(int key) {
        uint bucket = key % buckets;
        for (uint i=0; i<table[bucket].size(); ++i) {
            if (table[bucket][i].key == key) return table[bucket][i].value;
        }
        return null;
    }

    void add(int key, tilefilth@ value) {
        add(key, TileFilth(value));
    }

    void add(int key, TileFilth value) {
        uint bucket = key % buckets;

        // Check if it already exists
        for (uint i=0; i<table[bucket].size(); ++i) {
            if (table[bucket][i].key == key) {
                table[bucket][i] = Node(key, value);
                return;
            }
        }

        // Resize if neccessary
        if (size >= uint(0.7 * buckets)) {
            size = 0;
            buckets *= 2;
            bucket = key % buckets;
            // Yes, this copies the whole table, but handles can't be persisted :(
            array<array<Node>> old_table = table;
            table = array<array<Node>>(buckets);
            for (uint i=0; i<buckets/2; ++i) {
                for (uint j=0; j<old_table[i].size(); ++j) {
                    add(old_table[i][j].key, old_table[i][j].value);
                }
            }
        }

        // Add it
        ++size;
        table[bucket].insertLast(Node(key, value));
    }

    void remove(int key) {
        int bucket = key % buckets;
        for (uint i=0; i<table[bucket].size(); ++i) {
            if (table[bucket][i].key == key) {
                table[bucket].removeAt(i);
                --size;
                return;
            }
        }
    }
}

class HashMapIterator {
    HashMap@ m;
    uint bucket = 0;
    uint element = 0;

    HashMapIterator(HashMap@ m) {
        @this.m = m;
    }

    void reset() {
        bucket = 0;
        element = 0;
    }

    Node@ next() {
        while (bucket < m.buckets) {
            while (element < m.table[bucket].size()) {
                return m.table[bucket][element++];
            }
            ++bucket;
            element = 0;
        }
        return null;
    }
}

class Node {
    [hidden] int key;
    [hidden] TileFilth value;

    Node() {}

    Node(int key, TileFilth filth) {
        this.key = key;
        this.value = filth;
    }
}

class TileFilth {
    [hidden] bool top;
    [hidden] bool bottom;
    [hidden] bool left;
    [hidden] bool right;
    [hidden] int count;

    TileFilth() {}

    TileFilth(tilefilth@ filth) {
        int ft = filth.top();
        top = 0 < ft and ft <= 5;
        if (top) ++count;

        int fb = filth.bottom();
        bottom = 0 < fb and fb <= 5;
        if (bottom) ++count;

        int fl = filth.left();
        left = 0 < fl and fl <= 5;
        if (left) ++count;

        int fr = filth.right();
        right = 0 < fr and fr <= 5;
        if (right) ++count;

    }
}
