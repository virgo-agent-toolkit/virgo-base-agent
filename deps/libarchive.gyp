{
  'target_defaults': {
    'include_dirs': [
      'libarchive/libarchive',
    ]
  },
  'targets': [
    {
      'target_name': 'libarchive',
      'type': 'static_library',
      'conditions': [
         [ 'OS=="win"', {
	  'defines': [
            'PLATFORM_CONFIG_H=\"<(VIRGO_BASE_DIR)/deps/libarchive-configs/<(OS)-<(target_arch)-config.h\"'
	  ]
         },
         { 
	   'defines': [
             'PLATFORM_CONFIG_H=\"<(VIRGO_BASE_DIR)/deps/libarchive-configs/<(OS)-config.h\"'
            ]
	 }]
      ],
      'sources': [
        'libarchive/libarchive/archive_acl.c',
        'libarchive/libarchive/archive_check_magic.c',
        'libarchive/libarchive/archive_cmdline.c',
        'libarchive/libarchive/archive_crypto.c',
        'libarchive/libarchive/archive_entry.c',
        'libarchive/libarchive/archive_entry_copy_bhfi.c',
        'libarchive/libarchive/archive_entry_copy_stat.c',
        'libarchive/libarchive/archive_entry_link_resolver.c',
        'libarchive/libarchive/archive_entry_sparse.c',
        'libarchive/libarchive/archive_entry_stat.c',
        'libarchive/libarchive/archive_entry_strmode.c',
        'libarchive/libarchive/archive_entry_xattr.c',
        'libarchive/libarchive/archive_getdate.c',
        'libarchive/libarchive/archive_match.c',
        'libarchive/libarchive/archive_options.c',
        'libarchive/libarchive/archive_pathmatch.c',
        'libarchive/libarchive/archive_ppmd7.c',
        'libarchive/libarchive/archive_rb.c',
        'libarchive/libarchive/archive_read.c',
        'libarchive/libarchive/archive_read_append_filter.c',
        'libarchive/libarchive/archive_read_data_into_fd.c',
        'libarchive/libarchive/archive_read_disk_entry_from_file.c',
        'libarchive/libarchive/archive_read_disk_posix.c',
        'libarchive/libarchive/archive_read_disk_set_standard_lookup.c',
        'libarchive/libarchive/archive_read_extract.c',
        'libarchive/libarchive/archive_read_open_fd.c',
        'libarchive/libarchive/archive_read_open_file.c',
        'libarchive/libarchive/archive_read_open_filename.c',
        'libarchive/libarchive/archive_read_open_memory.c',
        'libarchive/libarchive/archive_read_set_format.c',
        'libarchive/libarchive/archive_read_set_options.c',
        'libarchive/libarchive/archive_read_support_format_zip.c',
        'libarchive/libarchive/archive_string.c',
        'libarchive/libarchive/archive_string_sprintf.c',
        'libarchive/libarchive/archive_util.c',
        'libarchive/libarchive/archive_virtual.c',
        'libarchive/libarchive/archive_windows.c',
        'libarchive/libarchive/archive_write.c',
        'libarchive/libarchive/archive_write_add_filter.c',
        'libarchive/libarchive/archive_write_disk_acl.c',
        'libarchive/libarchive/archive_write_disk_posix.c',
        'libarchive/libarchive/archive_write_disk_set_standard_lookup.c',
        'libarchive/libarchive/archive_write_open_fd.c',
        'libarchive/libarchive/archive_write_open_file.c',
        'libarchive/libarchive/archive_write_open_filename.c',
        'libarchive/libarchive/archive_write_open_memory.c',
        'libarchive/libarchive/archive_write_set_format.c',
        'libarchive/libarchive/archive_write_set_format_zip.c',
        'libarchive/libarchive/archive_write_set_options.c',
        'libarchive/libarchive/filter_fork_posix.c'
      ],
      'include_dirs': [
        'libarchive/libarchive',
        '<(VIRGO_BASE_DIR)/deps/luvit/deps/zlib'
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'libarchive/libarchive'
        ]
      }
    }
  ]
}

