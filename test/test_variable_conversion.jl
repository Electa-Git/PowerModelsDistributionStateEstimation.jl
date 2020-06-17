acp_sol["solution"]["gen"]["1"]["pg"]-(IVR_sol["solution"]["bus"]["4"]["vr"].*IVR_sol["solution"]["gen"]["1"]["crg"]+IVR_sol["solution"]["bus"]["4"]["vi"].*IVR_sol["solution"]["gen"]["1"]["cig"])

acp_sol["solution"]["gen"]["1"]["qg"]-(IVR_sol["solution"]["bus"]["4"]["vi"].*IVR_sol["solution"]["gen"]["1"]["crg"]-IVR_sol["solution"]["bus"]["4"]["vr"].*IVR_sol["solution"]["gen"]["1"]["cig"])

acp_sol["solution"]["gen"]["1"]["pg"]-(IVR_sol["solution"]["bus"]["4"]["vr"].*IVR_sol["solution"]["gen"]["1"]["crg"]+IVR_sol["solution"]["bus"]["4"]["vi"].*IVR_sol["solution"]["gen"]["1"]["cig"])

acp_sol["solution"]["branch"]["2"]["qf"]-(IVR_sol["solution"]["bus"]["2"]["vi"].*IVR_sol["solution"]["branch"]["2"]["cr_fr"]-IVR_sol["solution"]["bus"]["2"]["vr"].*IVR_sol["solution"]["branch"]["2"]["ci_fr"])

acp_sol["solution"]["load"]["3"]["qd"][1]-(IVR_sol["solution"]["bus"]["3"]["vi"][1]*IVR_sol["solution"]["load"]["3"]["crd_bus"][1]-IVR_sol["solution"]["bus"]["3"]["vr"][1]*IVR_sol["solution"]["load"]["3"]["cid_bus"][1])
