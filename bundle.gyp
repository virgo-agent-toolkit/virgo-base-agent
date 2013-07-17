{
  'variables': {
    'luas': [
      '<!@(cat <(BUNDLE_LIST_FILE) | sed -e "s/^/..\//" )',
    ],
  },
  'targets':
    [
      {
        'target_name': 'bundle.zip',
        'type': 'none',
        'actions': [{
          'action_name': 'bundle',
          'inputs': ['tools/gyp_utils.py', '<@(luas)'],
          'outputs': ["<(PRODUCT_DIR)/<(BUNDLE_NAME)-bundle.zip"],
          'action': [
            'python', 'tools/gyp_utils.py', 'make_bundle',
            '<(BUNDLE_DIR)', '<(BUNDLE_VERSION)', '<@(_outputs)', '<@(luas)'
          ]
        },
      ],
    }
  ]
}
