from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from screenings.models import Child, Screening, DomainScore, ReferralAction, FollowupOutcome, WorkforcePerformance


class Command(BaseCommand):
    help = 'Seed demo data for Problem C and D dashboards.'

    def handle(self, *args, **options):
        if Child.objects.exists():
            self.stdout.write(self.style.WARNING('Data already exists. Seeding skipped.'))
            return

        districts = ['ANANTAPUR', 'KURNOOL']
        mandals = ['MANDAL001', 'MANDAL002', 'MANDAL003']
        sectors = ['SEC001', 'SEC002']
        awcs = ['AWC001', 'AWC002', 'AWC003', 'AWC004']
        risks = ['Low', 'Medium', 'High', 'Critical']
        domains = ['GM', 'FM', 'LC', 'COG', 'SE']

        today = timezone.now().date()

        for i in range(1, 41):
            child = Child.objects.create(
                name=f'Child {i:03d}',
                gender='Female' if i % 2 == 0 else 'Male',
                awc_id=awcs[i % len(awcs)],
                sector_id=sectors[i % len(sectors)],
                mandal_id=mandals[i % len(mandals)],
                district_id=districts[i % len(districts)],
            )

            age = 6 + (i % 66)
            screening = Screening.objects.create(child=child, age_months=age)

            base_idx = i % 4
            for d_idx, domain in enumerate(domains):
                label = risks[(base_idx + d_idx) % 4]
                prob = {'Low': 0.2, 'Medium': 0.5, 'High': 0.75, 'Critical': 0.92}[label]
                DomainScore.objects.create(
                    screening=screening,
                    domain=domain,
                    probability=prob,
                    risk_label=label,
                )

            top_risk = risks[(base_idx + 2) % 4]
            referral_needed = top_risk in ('High', 'Critical')
            referral_date = today - timedelta(days=(i % 20))
            ReferralAction.objects.create(
                child=child,
                referral_required=referral_needed,
                referral_date=referral_date,
                referral_status='Pending' if referral_needed and i % 3 == 0 else 'Completed',
                completion_date=None if referral_needed and i % 3 == 0 else today - timedelta(days=(i % 7)),
            )

            baseline = 3 + (i % 8)
            followup = baseline - 1 if i % 2 == 0 else baseline + (1 if i % 5 == 0 else 0)
            status = 'Improving' if followup < baseline else ('Worsening' if followup > baseline else 'No Change')
            FollowupOutcome.objects.create(
                child=child,
                baseline_delay_months=baseline,
                followup_delay_months=max(0, followup),
                improvement_status=status,
                followup_completed=(i % 4 != 0),
                followup_date=today - timedelta(days=(i % 30)),
            )

        for awc in awcs:
            WorkforcePerformance.objects.create(
                awc_id=awc,
                aww_trained=True,
                supervisor_trained=True,
                cdpo_trained=(awc != 'AWC004'),
                training_mode='blended',
                parents_sensitized=30,
                parents_assigned_intervention=20,
            )

        self.stdout.write(self.style.SUCCESS('Seeded Problem C/D demo data successfully.'))
