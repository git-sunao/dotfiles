#!/usr/bin/env python
# author: stephan zimmer
# edits: surhud more (for consistency with python 3 and minor glitches)
# license: GPL
# date: 2018-01-27
# comment: script to shorten long (automatic) bibliographies to shorter names.
# requirement: https://bibtexparser.readthedocs.io
# usage: python shortenAuthors.py <bibfile> <number of names>
from argparse import ArgumentParser
from bibtexparser import loads as bib_loads, dumps as bib_dumps
from bibtexparser.bwriter import BibTexWriter

def loadDB(bibfile, max_authors):
    """ returns short author list """
    with open(bibfile) as bibtex_file:
        bibtex_str = bibtex_file.read()
    db = bib_loads(bibtex_str)
    for item in db.entries:
        try:
            auth = item['author']
        except:
            print ("Could not deal with :", item)
            continue
        #print auth
        auth_list = auth.split("and ")
        if len(auth_list) >= max_authors:
            all_auth = auth_list[0:max_authors]
            all_auth.append('others')
            item['author'] = "and ".join(all_auth)
    #print item
    return db

def main(args=None):
    parser = ArgumentParser(usage="Usage: %(prog)s [options]", description="shortens authorlist by replacing excess authors with 'others'")
    parser.add_argument("file", help="name of input bib file")
    parser.add_argument("-n","--nauthors",type=int, help="max number of authors", dest='max_authors', default=5)
    parser.add_argument("-o","--overwrite", help="name of output file, default will take input file and change to <file>-short.bib", action='store_true')
    opts = parser.parse_args(args)
    if opts.overwrite:
        out = opts.file
    else:
        out = opts.file.replace('.bib','-short.bib')
    db = loadDB(opts.file, opts.max_authors)
    writer = BibTexWriter()
    with open(out, 'w') as bibfile:
        #bibfile.write(bib_dumps(db, writer).encode("utf-8"))
        bibfile.write(bib_dumps(db, writer))
    print ('wrote %s'%out)

if __name__ == '__main__':
    main()
