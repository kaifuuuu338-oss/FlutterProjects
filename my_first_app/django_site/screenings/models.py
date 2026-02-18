from django.db import models

class Child(models.Model):
    name = models.CharField(max_length=100)
    dob = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, null=True, blank=True)
    awc_id = models.CharField(max_length=40, blank=True, default='')
    sector_id = models.CharField(max_length=40, blank=True, default='')
    mandal_id = models.CharField(max_length=40, blank=True, default='')
    district_id = models.CharField(max_length=40, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Question(models.Model):
    DOMAIN_CHOICES = [
        ('GM', 'Gross Motor'),
        ('FM', 'Fine Motor'),
        ('LC', 'Language & Communication'),
        ('COG', 'Cognitive'),
        ('SE', 'Socio-Emotional'),
    ]
    domain = models.CharField(max_length=4, choices=DOMAIN_CHOICES)
    age_band = models.CharField(max_length=20)
    text = models.TextField()
    weight = models.IntegerField(default=2)
    is_red_flag = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.domain} ({self.age_band}): {self.text[:40]}"

class Screening(models.Model):
    child = models.ForeignKey(Child, on_delete=models.CASCADE)
    date = models.DateTimeField(auto_now_add=True)
    age_months = models.IntegerField()

    def __str__(self):
        return f"Screening for {self.child.name} at {self.date}"

class Response(models.Model):
    screening = models.ForeignKey(Screening, on_delete=models.CASCADE)
    question = models.ForeignKey(Question, on_delete=models.CASCADE)
    answer = models.IntegerField()  # 0=Not yet, 1=Emerging, 2=Achieved

    def __str__(self):
        return f"{self.screening} - {self.question}: {self.answer}"

class DomainScore(models.Model):
    screening = models.ForeignKey(Screening, on_delete=models.CASCADE)
    domain = models.CharField(max_length=4)
    probability = models.FloatField()
    risk_label = models.CharField(max_length=20)

    def __str__(self):
        return f"{self.screening} - {self.domain}: {self.risk_label}"


class ReferralAction(models.Model):
    STATUS_CHOICES = [
        ('Pending', 'Pending'),
        ('Completed', 'Completed'),
        ('Under Treatment', 'Under Treatment'),
    ]
    child = models.ForeignKey(Child, on_delete=models.CASCADE)
    referral_required = models.BooleanField(default=False)
    referral_date = models.DateField(null=True, blank=True)
    referral_status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='Pending')
    completion_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.child.name} - {self.referral_status}"


class FollowupOutcome(models.Model):
    STATUS_CHOICES = [
        ('Improving', 'Improving'),
        ('Worsening', 'Worsening'),
        ('No Change', 'No Change'),
    ]
    child = models.ForeignKey(Child, on_delete=models.CASCADE)
    baseline_delay_months = models.IntegerField(default=0)
    followup_delay_months = models.IntegerField(default=0)
    improvement_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='No Change')
    followup_completed = models.BooleanField(default=False)
    followup_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.child.name} - {self.improvement_status}"


class WorkforcePerformance(models.Model):
    awc_id = models.CharField(max_length=40)
    aww_trained = models.BooleanField(default=False)
    supervisor_trained = models.BooleanField(default=False)
    cdpo_trained = models.BooleanField(default=False)
    training_mode = models.CharField(max_length=20, blank=True, default='')
    parents_sensitized = models.IntegerField(default=0)
    parents_assigned_intervention = models.IntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.awc_id
