def if_local_sycl_toolkit(if_true, if_false = []):
    is_local_stk = %{is_local_stk}
    if is_local_stk:
        return if_true
    else:
        return if_false

def if_deliverable_sycl_toolkit(if_true, if_false = []):
    return if_local_sycl_toolkit(if_false, if_true)
