from django.db import models

class Child(models.Model):
    name = models.CharField(max_length=100)
    dob = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, null=True, blank=True)
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
