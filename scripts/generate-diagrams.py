#!/usr/bin/env python3
"""Generate architecture/diagrams/*.png (pip install diagrams; needs graphviz `dot`).

Colour convention:
  blue   = consumed from the AWS Enterprise Landing Zone (read through remote state, never recreated)
  amber  = created by this repository in af-south-1
  grey   = delivery tooling and people
"""
import os

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb
from diagrams.aws.devtools import XRay
from diagrams.aws.engagement import Connect
from diagrams.aws.integration import SNS
from diagrams.aws.management import Cloudwatch, Organizations
from diagrams.aws.ml import Lex
from diagrams.aws.network import VPC
from diagrams.aws.security import IAM, KMS, SecretsManager
from diagrams.aws.storage import S3
from diagrams.onprem.client import Client, Users
from diagrams.onprem.vcs import Github

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "architecture", "diagrams")
os.makedirs(OUT, exist_ok=True)
LZ = {"bgcolor": "#E8F0FE", "pencolor": "#1A73E8", "style": "rounded", "fontsize": "13"}
FRONT = {"bgcolor": "#FFF4E0", "pencolor": "#FF9900", "style": "rounded", "fontsize": "13"}
TOOL = {"bgcolor": "#F1F3F4", "pencolor": "#5F6368", "style": "rounded", "fontsize": "13"}
G = {"fontsize": "20", "pad": "0.5", "nodesep": "0.6", "ranksep": "0.9"}


def d(name, title, direction="LR"):
    return Diagram(title, filename=os.path.join(OUT, name), show=False, direction=direction, graph_attr=G, outformat="png")


with d("executive-architecture", "Contact centre on Amazon Connect - executive view"):
    caller = Users("Customers\n(phone, chat)")
    agent = Client("Agents and\nsupervisors")
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        lz = Organizations("Org guardrail, alerts,\nkey strategy, OIDC")
    with Cluster("af-south-1 (created)", graph_attr=FRONT):
        cc = Connect("Amazon Connect\nflows, queues, routing")
        bot = Lex("Lex V2 bot\n(en_ZA)")
        fn = Lambda("CRM lookup,\ncallback")
        db = Dynamodb("Customers, callbacks,\ninteractions")
        rec = S3("Recordings and\ntranscripts")
    caller >> cc
    cc >> bot
    cc >> fn >> db
    cc >> rec
    cc >> agent
    lz - Edge(style="dotted") - cc

with d("landing-zone-integration", "Landing Zone integration: consumed vs created", direction="TB"):
    with Cluster("Landing Zone (consumed - never recreated)", graph_attr=LZ):
        state = S3("Remote state\n(contract v2)")
        topic = SNS("Monitoring topic\n(af-south-1)")
        keys = KMS("key_strategy and\nshared s3 / analytics keys")
        oidc = IAM("GitHub OIDC\nprovider")
        org = Organizations("Organization ID")
    with Cluster("This repository (created, af-south-1)", graph_attr=FRONT):
        cc = Connect("Connect instance,\nflows, Lex")
        mon = Cloudwatch("Dashboard + alarms")
        roles = IAM("Plan / apply roles")
        tbl = Dynamodb("Tables")
    state >> cc
    keys >> Edge(label="CMK only if set") >> tbl
    topic << mon
    oidc >> roles
    org >> Edge(label="aws:PrincipalOrgID") >> tbl

with d("data-flow", "Call data flow"):
    caller = Users("Caller")
    with Cluster("af-south-1", graph_attr=FRONT):
        cc = Connect("Inbound flow")
        crm = Lambda("crm-lookup")
        cust = Dynamodb("customers")
        key = SecretsManager("HMAC key")
        bot = Lex("Lex V2")
        cb = Lambda("callback")
        cbt = Dynamodb("callbacks (TTL)")
        inter = Dynamodb("interactions (TTL)")
        rec = S3("Recordings")
        agent = Client("Agent")
    caller >> Edge(label="1 call") >> cc
    cc >> Edge(label="2 number") >> crm
    crm >> key
    crm >> Edge(label="3 tier") >> cust
    crm >> inter
    cc >> Edge(label="4 self-service") >> bot
    cc >> Edge(label="5 closed or full") >> cb >> cbt
    cc >> Edge(label="6 queue") >> agent
    cc >> Edge(label="record") >> rec

with d("dr-resilience", "Resilience: what survives a Region loss", direction="LR"):
    with Cluster("af-south-1 (Connect is not offered in eu-west-1)", graph_attr=FRONT):
        cc = Connect("Connect instance\n(rebuilt from Terraform)")
        tbl = Dynamodb("Tables\n(PITR in test and prod)")
        rec = S3("Recordings\n(versioned, expiry)")
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        bk = S3("Backup vault\n(available)")
    tbl >> Edge(style="dotted", label="export / backup") >> bk

with d("logical-architecture", "Logical architecture", direction="TB"):
    with Cluster("Channels", graph_attr=FRONT):
        cc = Connect("Voice and chat")
    with Cluster("Self-service", graph_attr=FRONT):
        bot = Lex("Lex V2: SpeakToAgent,\nOpeningHours, RequestCallback")
    with Cluster("Integration (af-south-1)", graph_attr=FRONT):
        l1 = Lambda("crm-lookup")
        l2 = Lambda("callback")
    with Cluster("Data", graph_attr=FRONT):
        t1 = Dynamodb("customers")
        t2 = Dynamodb("callbacks")
        t3 = Dynamodb("interactions")
        s3 = S3("Recordings")
    cc >> bot
    cc >> [l1, l2]
    l1 >> [t1, t3]
    l2 >> t2
    cc >> s3

with d("network-architecture", "Network and traffic paths", direction="LR"):
    pstn = Users("PSTN callers")
    web = Client("Agent browsers\n(softphone, WebRTC)")
    with Cluster("af-south-1 regional services (no VPC attachment)", graph_attr=FRONT):
        cc = Connect("Connect")
        fn = Lambda("Lambda")
        ddb = Dynamodb("DynamoDB")
        lex = Lex("Lex V2")
    with Cluster("Landing Zone", graph_attr=LZ):
        vpc = VPC("VPCs exist; unused\n(no endpoints)")
    pstn >> cc
    web >> cc
    cc >> fn >> ddb
    cc >> lex
    vpc - Edge(style="dotted") - fn

with d("security-architecture", "Security controls", direction="TB"):
    users = Users("Agents")
    with Cluster("Controls (created)", graph_attr=FRONT):
        sp = Connect("Security profiles:\nagent | supervisor")
        iam = IAM("One least-privilege\nrole per function")
        key = SecretsManager("Phone numbers hashed\n(HMAC), never logged")
        ddb = Dynamodb("SSE, PITR, TTL")
        s3 = S3("Recordings: private, TLS-only,\nversioned, expiry")
        xr = XRay("Tracing (optional)")
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        org = Organizations("Org guardrail")
        keys = KMS("key_strategy")
    users >> sp >> iam
    iam >> key
    iam >> ddb
    sp >> s3
    org - Edge(style="dotted") - ddb
    keys - Edge(style="dotted") - s3
    iam >> xr

with d("terraform-deployment", "Terraform deployment and CI/CD"):
    with Cluster("GitHub", graph_attr=TOOL):
        gh = Github("PR: fmt, validate,\ntests, tfsec, checkov,\ntrivy, gitleaks, bandit")
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        oidc = IAM("OIDC provider")
        st = S3("State bucket")
    with Cluster("This repository (created)", graph_attr=FRONT):
        plan = IAM("Plan role\n(read-only)")
        apply_ = IAM("Apply role\n(environment gate)")
        wl = Connect("af-south-1 stack\n(aws + awscc providers)")
    gh >> oidc
    oidc >> plan
    oidc >> apply_
    plan >> Edge(label="terraform plan") >> st
    apply_ >> Edge(label="terraform apply") >> wl
    apply_ >> st
