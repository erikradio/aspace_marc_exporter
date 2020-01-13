# What is this

/plugins/local/backend

# Why is this here

Extensions to the ArchivesSpace exporters, and the means by which resource_tree.component_id is populated

# How so

The EAC exporter is customized so that it doesn't export linked records. It's a work in progress. The MARC exporter takes care of customizations that were formerly dealt with in post-processing, like adding RDA 33X fields and other local fields we use for collection management purposes in our ILS.

In the 'model' folder is the means by which component_id is populated in the tree viewer; it checks to see if the current node is a resource (in which case it gets the value of id_0) or an archival object (in which case it gets the value of component_id).
