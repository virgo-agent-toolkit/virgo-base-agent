{
  'targets':
  [
    {
      'target_name': 'bundle.zip',
      'type': 'none',
      'actions': [
        {
          'action_name': 'bundle',
          'inputs': ['tools/gyp_utils.py', '<@(BUNDLE_LIST_FILE)', '<@(BUNDLE_FILES)'],
          'outputs': ["<(PRODUCT_DIR)/<(BUNDLE_NAME)-bundle.zip"],
          'action': [
            'python', 'tools/gyp_utils.py', 'make_bundle',
            '<(BUNDLE_DIR)', '<(BUNDLE_VERSION)', '<@(_outputs)', '<@(BUNDLE_LIST_FILE)'
          ]
        },
      ],
    },
    {
      'target_name': 'bundle.zip.embed',
      'type': 'none',
      'dependencies': [
        'bundle.zip',
      ],
      'actions': [
        {
          'action_name': 'bundle_embed',
          'inputs': ['tools/gyp_utils.py', '<@(BUNDLE_LIST_FILE)', '<@(BUNDLE_FILES)'],
          'outputs': ["<(PRODUCT_DIR)/bundle.zip"],
          'action': [
            'python', 'tools/gyp_utils.py', 'make_bundle',
            '<(BUNDLE_DIR)', '<(BUNDLE_VERSION)', '<@(_outputs)', '<@(BUNDLE_LIST_FILE)'
          ]
        },
      ],
    },
    {
      'target_name': 'bundle.h',
      'type': 'none',
      'dependencies': [
        'bundle.zip.embed',
      ],
      'actions': [
        {
          'action_name': 'bundle_h',
          'inputs': ['<(PRODUCT_DIR)/bundle.zip'],
          'outputs': ['<(SHARED_INTERMEDIATE_DIR)/bundle.h'],
          'action': [
            'python', 'tools/bin2c.py', '<(PRODUCT_DIR)/bundle.zip', '<(SHARED_INTERMEDIATE_DIR)/bundle.h'
          ]
        },
      ],
    }
  ]
}
