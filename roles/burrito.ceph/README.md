burrito.ceph
=============

Ansible role to install ceph for Burrito

Requirements
------------

This role requires Ansible 2.16 or higher.

This role supports:

  - Debian 12 (bookworm)
  - Rocky Linux 8.x

Role Variables
--------------

[defaults/main.yml](defaults/main.yml)

Dependencies
------------

[ansible-galaxy-requirements.yml](ansible-galaxy-requirements.yml)

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    hosts: all
    roles:
      - {role: burrito.ceph tags: ceph}

License
-------

  - Code released under [Apache License 2.0](LICENSE)
  - Docs released under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/)

Author Information
------------------

  - Heechul Kim @iOrchard
      - <https://github.com/iorchard>

