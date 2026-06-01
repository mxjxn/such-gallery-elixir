# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs

Code.require_file("seeds/templates.exs", __DIR__)
SuchGalleryElixir.Seeds.Templates.run()
