

def calc_shared_columns(schemas):
    """Given a list of strings representing the columns of a set of data sets (as in meta-data.csv) return the set of columns shared by all the data sets."""
    if len(schemas) == 1:
        return schemas[0].split(", ");
    else:
        st = set(schemas[0].split(", "));
        for item in schemas:
            st = st.intersection(item.split(", "));
        return list(st);
