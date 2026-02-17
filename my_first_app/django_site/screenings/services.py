import math

# Weighted scoring engine (port of your Dart logic)
def compute_domain_score(responses, weights):
    S = sum(a * w for a, w in zip(responses, weights))
    T = 0.5 * sum(weights)
    try:
        P = 1 / (1 + math.exp(-(S - T)))
    except OverflowError:
        P = 0.0 if S < T else 1.0
    return P

def domain_score_to_risk_label(score):
    if score < 0.3:
        return 'Low'
    elif score < 0.6:
        return 'Medium'
    elif score < 0.85:
        return 'High'
    else:
        return 'Critical'

def overall_risk_from_domains(domain_scores):
    return max(domain_scores)
