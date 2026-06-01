# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs

Code.require_file("seeds/templates.exs", __DIR__)
Code.require_file("seeds/demo.exs", __DIR__)

SuchGalleryElixir.Seeds.Templates.run()
SuchGalleryElixir.Seeds.Demo.run()
