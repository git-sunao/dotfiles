#!/usr/bin/env python
"""
This delete some specified key from all the entries in the specified bib file.

Author: Sunao Sugiyama
"""
import bibtexparser
import argparse


# Define a function to remove the "title" entry from each BibTeX entry
def remove_title(bib_database, keys):
    for key in keys:
        print('removing {} from all entries'.format(key))
        for entry in bib_database.entries:
            if key in entry:
                del entry[key]

def main(filename, keys, overwrie=False):
    # Load the .bib file
    with open(filename, 'r', encoding='utf-8') as bibfile:
        bib_database = bibtexparser.load(bibfile)

    # Remove the "title" entries
    remove_title(bib_database, keys)

    # Save the modified .bib file
    filename_out = filename if overwrie else filename.replace('.bib', '-del.bib')
    with open(filename_out, 'w', encoding='utf-8') as output_bibfile:
        bibtexparser.dump(bib_database, output_bibfile)

    print("Title entries removed and saved to '{}'.".format(filename_out))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=str, help="bib file name")
    parser.add_argument("-k","--keys", help="keys to delete", type=list, default=['abstract', 'local-url', 'language'])
    parser.add_argument("-o","--overwrite", help="overwrite the original file", action="store_true")
    opts = parser.parse_args()

    main(opts.file, opts.keys, opts.overwrite)
