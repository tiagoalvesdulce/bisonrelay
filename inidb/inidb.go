// Copyright (c) 2016 Company 0, LLC.
// Use of this source code is governed by an ISC
// license that can be found in the LICENSE file.

// inidb package uses a regular ini file as a database.  Ini sections are
// considered tables.  Individual  entries are considered records and are
// key = value pairs.
//
// The package assumes that the user will create a single inidb per directory.
package inidb

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/vaughan0/go-ini"
)

const (
	auto = "# This file is autogenerated, DO NOT EDIT!"
)

var (
	ErrNotFound = errors.New("record not found")
	ErrCreated  = errors.New("database created")
)

// INIDB is an opaque structure that contains the database context.
type INIDB struct {
	mtx      sync.Mutex // mutex for this structure
	filename string     // inidb full path
	depth    int        // max journal files that are kept
	dirty    bool       // like your mom
	created  bool       // db was created
	tables   ini.File   // ini sections
}

// New returns a new INIDB context.  Depth contains the maximum number of files
// that are retained.  Create indicates if the database should be created if it
// doesn't exist. If depth is negative there is no limit.  If the ini file does
// not exist it returns an error.
// The inidb package assumes there is only one inidb per directory.  DO NOT
// CREATE MULTIPLE INIDBS IN A SINGLE DIRECTORY.
func New(filename string, create bool, depth int) (*INIDB, error) {
	i := INIDB{
		filename: filename,
		depth:    depth,
	}

	_, err := os.Stat(filepath.Dir(filename))
	if os.IsNotExist(err) && create {
		err = os.MkdirAll(filepath.Dir(filename), 0700)
		if err != nil {
			return nil, fmt.Errorf("could not create directory: %v",
				err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("could not create lock %v: %v",
			filepath.Dir(filename), err)
	}

	i.tables, err = ini.LoadFile(filename)
	i.tables.Section("") // default always exists
	if os.IsNotExist(err) && create {
		// save empty file
		i.created = true
		i.dirty = true
		err2 := i.Save()
		if err2 != nil {
			return nil, err2
		}

		err = ErrCreated // indicate we just created it
	} else if err != nil {
		return nil, fmt.Errorf("could not open %v: %v", filename, err)
	}

	return &i, err
}

// Save flushes current in memory database back to disk.  The process is as
// follows:
//  1. Check if the database is dirty and abort process if it isn't
//  2. Create temporary file that contains all memory tables and records
//  3. Backup original file
//  4. Rename temporary file to the original file name
//
// This creates a running log of flushes.
//
// NOTE: currently there is no file count limiter.
func (i *INIDB) Save() error {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	if !i.dirty {
		return nil
	}

	f, err := os.CreateTemp(filepath.Dir(i.filename), filepath.Base(i.filename))
	if err != nil {
		return fmt.Errorf("could not create temporary file: %v", err)
	}

	// save all records
	fmt.Fprintf(f, "%v\n", auto)
	for tk, tv := range i.tables {
		if tk != "" {
			fmt.Fprintf(f, "[%v]\n", tk)
		}
		for rk, rv := range tv {
			fmt.Fprintf(f, "%v = %v\n", rk, rv)
		}
		fmt.Fprintf(f, "\n")
	}
	f.Close()

	// backup original
	if !i.created {
		backup := fmt.Sprintf("%v.%v",
			i.filename,
			time.Now().Format("20060102.150405.000000000"))
		err = os.Rename(i.filename, backup)
		if err != nil {
			return fmt.Errorf("could not rename original file: %v",
				err)
		}
	}

	// rename new one
	err = os.Rename(f.Name(), i.filename)
	if err != nil {
		return fmt.Errorf("could not rename new file: %v", err)
	}

	i.dirty = false

	return i.prune()
}

func (i *INIDB) prune() error {
	if i.depth < 0 {
		return nil
	}

	d, err := os.ReadDir(filepath.Dir(i.filename))
	if err != nil {
		return fmt.Errorf("could not read directory %v: %v",
			filepath.Dir(i.filename), err)
	}

	// create prune list
	pl := make([]string, 0, len(d))
	find := filepath.Base(i.filename) + "."
	for _, v := range d {
		if !strings.HasPrefix(v.Name(), find) {
			continue
		}
		pl = append(pl, v.Name())
	}

	// actually prune
	if len(pl)-i.depth < 0 {
		return nil
	}

	for _, v := range pl[:len(pl)-i.depth] {
		_ = os.Remove(filepath.Join(filepath.Dir(i.filename), v))
	}

	return nil
}

// Get returns a record from table.  If the record does not exist ErrNotFound
// is returned.
func (i *INIDB) Get(table string, key string) (string, error) {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	value, ok := i.tables.Get(table, key)
	if !ok {
		return "", ErrNotFound
	}

	return value, nil
}

// Set creates/overwrites a record in table.  If table does not exist
// ErrNotFound is returned.
func (i *INIDB) Set(table, key, value string) error {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	s, ok := i.tables[table]
	if !ok {
		return ErrNotFound
	}
	s[key] = value
	i.dirty = true

	return nil
}

// Del remove a record from a table.
func (i *INIDB) Del(table, key string) error {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	s, ok := i.tables[table]
	if !ok {
		return ErrNotFound
	}

	delete(s, key)
	i.dirty = true

	return nil
}

// NewTable creates a new table.
func (i *INIDB) NewTable(table string) {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	i.tables.Section(table)
}

// DelTable deletes an entire table including all records.
func (i *INIDB) DelTable(table string) error {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	_, ok := i.tables[table]
	if !ok {
		return ErrNotFound
	}

	delete(i.tables, table)
	i.dirty = true

	return nil
}

// Records returns a copy of all records in the given table.
func (i *INIDB) Records(table string) map[string]string {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	t := make(map[string]string)
	for k, v := range i.tables[table] {
		t[k] = v
	}

	return t
}

// Tables returns a copy of all tables in the inidb.
func (i *INIDB) Tables() []string {
	i.mtx.Lock()
	defer i.mtx.Unlock()

	tables := make([]string, 0, len(i.tables))

	for k := range i.tables {
		tables = append(tables, k)
	}

	return tables
}
